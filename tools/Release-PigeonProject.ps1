<#
.SYNOPSIS
    Releases a project without a local copy: updates the version and CHANGELOG on GitLab, waits for the checks,
    then tags.

.DESCRIPTION
    1. Moves what's under Unreleased in CHANGELOG.md into a section for the new version and today's date, and sets
       the version in every fxmanifest.lua and package.json.
    2. Commits that to main on GitLab and waits for its pipeline. If the checks fail, it stops before tagging,
       because a v* tag can't be moved or deleted. Fix what they found and run this again.
    3. Tags the commit. The tag's pipeline does the rest (handbook: Shared CI checks and releases).

    It's safe to run again: a version already committed isn't committed twice, and a tag already there stops it.

    Paid projects: this is step 4 of the handbook's Releasing page. It only tags. The upload and the publish job
    stay with you, after the owner's go-ahead.

.PARAMETER Slug
    The project: "notes", "pigeon-notes" or "shrike".

.PARAMETER Version
    The new version, such as 1.2.0. Use this or -Bump.

.PARAMETER Bump
    patch, minor or major: the new version worked out from the current one. Use this or -Version.

.PARAMETER DryRun
    Run the checks and print the new CHANGELOG section, and change nothing.

.EXAMPLE
    .\tools\Release-PigeonProject.ps1 -Slug notes -Version 1.0.0 -DryRun

.EXAMPLE
    .\tools\Release-PigeonProject.ps1 -Slug dice -Bump patch
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Slug,
    [ValidatePattern('^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$')] [string] $Version,
    [ValidateSet('patch', 'minor', 'major')] [string] $Bump,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PigeonCommon.ps1')

if ([bool] $Version -eq [bool] $Bump) { throw 'Give either -Version or -Bump.' }
Assert-GitLabToken
$project = Find-PigeonProject $Slug
$free = $project.path_with_namespace -notmatch '/dev-releases/' -and (Get-ProjectFile $project '.gitlab-ci.yml') -match '(?m)^\s*PS_RELEASE_KIND:\s*free'
Write-Host "  GitLab project    $($project.web_url)"

# --- What's there now -----------------------------------------------------------------------------

$tree = Get-ProjectTree $project
if ($tree -contains '.ps-check.json') { throw "$($project.path) keeps its version in a file named by .ps-check.json. Release it by hand (handbook: Releasing)." }
if ($tree -notcontains 'CHANGELOG.md') { throw "$($project.path) has no CHANGELOG.md." }

# A build template (version '${V}') is filled in later, so it states no version of its own.
$versionFiles = @{}
foreach ($file in $tree) {
    if ((Split-Path -Leaf $file) -eq 'fxmanifest.lua') {
        $text = Get-ProjectFile $project $file
        if ($text -match "(?m)^\s*version\s+['""]([^'""]+)['""]" -and $Matches[1] -notmatch '\$\{') { $versionFiles[$file] = @{ Text = $text; Version = $Matches[1] } }
    } elseif ($file -eq 'package.json') {
        $text = Get-ProjectFile $project $file
        $versionFiles[$file] = @{ Text = $text; Version = ($text | ConvertFrom-Json).version }
    }
}
if (-not $versionFiles.Count) { throw 'No version found in any fxmanifest.lua or package.json.' }
$current = @($versionFiles.Values | ForEach-Object { $_.Version } | Sort-Object -Unique)
if ($current.Count -gt 1) { throw "The version differs between files: $($current -join ', '). Fix that first." }
$current = $current[0]

if ($Bump) { $Version = Get-NextVersion $current $Bump }
$tag = "v$Version"
Write-Host "  Version           $current -> $Version"

if ((Get-Url "$api/projects/$($project.id)/repository/tags/$tag" $headers).Status -eq 200) {
    throw "$tag is already tagged on $($project.path), and tags are never moved. Choose the next version."
}
if ($free) {
    $mirrors = @(Invoke-GitLab GET "/projects/$($project.id)/remote_mirrors")
    if (-not $mirrors) { throw "$($project.path) has no GitHub mirror yet. Run Publish-PigeonProject.ps1 first." }
}

$changelog = Get-ProjectFile $project 'CHANGELOG.md'
$alreadyCommitted = $changelog -match "(?m)^## \[$([regex]::Escape($Version))\]" -and $current -eq $Version
$newChangelog = $null
if ($alreadyCommitted) {
    Write-Host "  $Version is already in CHANGELOG.md and the version files; going straight to the checks." -ForegroundColor DarkGray
} else {
    if ($changelog -match "(?m)^## \[$([regex]::Escape($Version))\]") { throw "CHANGELOG.md already has a section for $Version, but the version files say $current. Fix that first." }
    $repoUrl = if ($free) { "https://github.com/$org/$($project.path)" } else { $project.web_url }
    $date = (Get-Date).ToString('yyyy-MM-dd')
    $newChangelog = Update-Changelog $changelog $Version $date $repoUrl $free
    $preview = [regex]::Match($newChangelog, "(?ms)^## \[$([regex]::Escape($Version))\].*?(?=^## \[|^<!--|^\[[^\]]+\]: |\z)").Value.Trim()
    Write-Host ''
    Write-Host $preview
    Write-Host ''
}

if ($DryRun) { Write-Host 'Dry run: nothing changed.' -ForegroundColor Yellow; return }

# --- Commit ---------------------------------------------------------------------------------------

if (-not $alreadyCommitted) {
    $actions = @(@{ action = 'update'; file_path = 'CHANGELOG.md'; content = $newChangelog })
    foreach ($file in $versionFiles.Keys) {
        $text = $versionFiles[$file].Text
        $updated = if ($file -eq 'package.json') { Set-PackageVersion $text $Version } else { Set-ManifestVersion $text $Version }
        $actions += @{ action = 'update'; file_path = $file; content = $updated }
    }
    Invoke-GitLab POST "/projects/$($project.id)/repository/commits" @{
        branch = $project.default_branch; commit_message = "$($project.name) $Version"
        author_name = 'Pigeon'; author_email = 'pigeonstudiosllc@gmail.com'; actions = $actions
    } | Out-Null
    Write-Host "  Committed $Version to $($project.default_branch)." -ForegroundColor Green
}

# --- Checks ---------------------------------------------------------------------------------------

$head = (Invoke-GitLab GET "/projects/$($project.id)/repository/commits/$($project.default_branch)").id
$status = $null
Write-Host '  Waiting for the checks...'
for ($i = 0; $i -lt 60; $i++) {
    $pipeline = @(Invoke-GitLab GET "/projects/$($project.id)/pipelines?sha=$head&per_page=1") | Select-Object -First 1
    $status = if ($pipeline) { $pipeline.status } else { $null }
    if ($status -in 'success', 'failed', 'canceled', 'skipped', 'manual') { break }
    Start-Sleep -Seconds 10
}
if ($status -notin 'success', 'skipped', 'manual') {
    $where = if ($pipeline) { $pipeline.web_url } else { $project.web_url }
    throw "The checks ended as '$status', so nothing was tagged: $where. Fix what they found and push, then run this again."
}
Write-Host "  Checks: $status." -ForegroundColor Green

# --- Tag ------------------------------------------------------------------------------------------

Invoke-GitLab POST "/projects/$($project.id)/repository/tags" @{ tag_name = $tag; ref = $head; message = "$($project.name) $Version" } | Out-Null
Write-Host "  Tagged $tag." -ForegroundColor Green
Write-Host ''
if ($free) {
    Write-Host "$($project.name) $Version is on its way. The mirror and GitHub build the release, and about 8 minutes after the checks pass," -ForegroundColor Cyan
    Write-Host 'publish adds it to the registry, Announcements and, on a first release, the Overview. The bot posts it to Discord.' -ForegroundColor Cyan
} else {
    Write-Host "Tagged. Next: the Tebex project, the Cfx.re upload, then press Run on publish (handbook: Releasing)." -ForegroundColor Cyan
}
Write-Host "$($project.web_url)/-/pipelines"
