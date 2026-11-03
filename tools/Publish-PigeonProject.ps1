<#
.SYNOPSIS
    Makes a free project public: the GitHub repository, its rulesets and the GitLab push mirror.

.DESCRIPTION
    Run it when a project made with New-PigeonProject.ps1 is ready to be seen. It works from GitLab, so no local
    copy is needed, and it's safe to run again: each step looks first and only does what's missing.

    First it refuses if the project isn't ready: placeholders left in the README, images it shows that don't
    exist, or no GitHub release workflow. Nothing empty is ever public.

    Then it sets up the public GitHub repository (description, website, topics), the two rulesets from the
    handbook, the GitLab push mirror over SSH with GitHub's host keys, its deploy key with write access, the
    GitHub badge on GitLab, and one mirror push. The website finds the repository and adds its webhook on its
    next hourly refresh. The Overview page and the Discussions forms are updated by the first release.

.PARAMETER Slug
    The project: "notes" or "pigeon-notes".

.PARAMETER DryRun
    Run the checks and print what would happen, and change nothing.

.EXAMPLE
    .\tools\Publish-PigeonProject.ps1 -Slug notes -DryRun

.EXAMPLE
    .\tools\Publish-PigeonProject.ps1 -Slug notes
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Slug,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PigeonCommon.ps1')

Assert-GitLabToken
Assert-GitHubToken

$project = Find-PigeonProject $Slug
if ($project.path_with_namespace -match '/(dev-releases)/') { throw "$($project.path_with_namespace) is a paid project. Paid work never goes on GitHub." }
$path = $project.path
$githubUrl = "https://github.com/$org/$path"
Write-Host "  GitLab project    $($project.web_url)"
Write-Host "  GitHub            $githubUrl"

# --- Is it ready? ---------------------------------------------------------------------------------

$tree = Get-ProjectTree $project
if (-not $tree) { throw "$($project.web_url) is empty. Push the project first." }
$problems = New-Object System.Collections.Generic.List[string]
$readme = Get-ProjectFile $project 'README.md'
if (-not $readme) { $problems.Add('There is no README.md.') }
else {
    $placeholders = @([regex]::Matches($readme, '\{\{[A-Z_]+\}\}') | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($placeholders) { $problems.Add("README.md still has placeholders: $($placeholders -join ', ').") }
    foreach ($image in [regex]::Matches(($readme -replace '(?s)<!--.*?-->', ''), '<img src="(?!https?:)([^"]+)"')) {
        if ($tree -notcontains $image.Groups[1].Value) { $problems.Add("README.md shows $($image.Groups[1].Value), which doesn't exist.") }
    }
}
foreach ($file in 'LICENSE.md', 'CHANGELOG.md', '.github/workflows/release.yml') {
    if ($tree -notcontains $file) { $problems.Add("$file is missing.") }
}
if ($problems.Count) { throw "$path isn't ready to be public. Fix these, push, and run this again:`n  $($problems -join "`n  ")" }
Write-Host '  Ready: README filled in, images present, release workflow in place.' -ForegroundColor Green

# GitHub matches the released free repositories: "<sentence>. Free.", the Free releases page as the website,
# and pigeonstudios-release, which marks our releases. fivem, free and github would only repeat the obvious.
$manifest = Get-ProjectFile $project 'fxmanifest.lua'
$package = Get-ProjectFile $project 'package.json'
$sentence = if ($manifest -and $manifest -match "(?m)^\s*description\s+'((?:[^'\\]|\\.)*)'") { $Matches[1].Replace("\'", "'") }
elseif ($package) { ($package | ConvertFrom-Json).description }
if (-not $sentence) { throw 'No description in fxmanifest.lua or package.json, which the GitHub About panel needs.' }
$githubDescription = "$($sentence.TrimEnd('.')). Free."
$githubTopics = @((@($project.topics | Where-Object { $_ -notin 'fivem', 'free', 'github' }) + 'pigeonstudios-release') | Sort-Object -Unique)
Write-Host "  GitHub about      $githubDescription"
Write-Host "  GitHub topics     $($githubTopics -join ', ')"

$rulesetFiles = 'protect-main.json', 'protect-release-tags.json'
$handbook = [pscustomobject]@{ id = [uri]::EscapeDataString("$gitlabGroup/handbook"); default_branch = 'main' }
$rulesets = @{}
foreach ($file in $rulesetFiles) {
    $text = Get-ProjectFile $handbook "github/rulesets/$file"
    if (-not $text) { throw "Couldn't read github/rulesets/$file from the handbook on GitLab." }
    $rulesets[$file] = $text
}

$repo = Get-Url "https://api.github.com/repos/$org/$path" $ghHeaders
$repoExists = $repo.Status -eq 200
$live = if ($repoExists) { $repo.Content | ConvertFrom-Json } else { $null }
if ($DryRun) {
    Write-Host ''
    Write-Host "  GitHub repository $(if ($repoExists) { 'exists; only missing settings would be added' } else { 'would be created' })."
    Write-Host 'Dry run: nothing changed.' -ForegroundColor Yellow
    return
}

# --- GitHub repository ----------------------------------------------------------------------------

if ($repoExists) {
    Write-Host '  GitHub repository already exists.' -ForegroundColor DarkGray
} else {
    Invoke-GitHub POST "/orgs/$org/repos" @{ name = $path; private = $false; auto_init = $false } | Out-Null
    Write-Host "  GitHub repository created: $githubUrl" -ForegroundColor Green
}
# Only what's missing: a repository that's already public may have been edited since, and the website reads its
# frameworks from the topics, so nothing here is ever overwritten or removed.
$missing = @{}
if (-not $live.description) { $missing.description = $githubDescription }
if (-not $live.homepage) { $missing.homepage = 'https://pigeonstudios.co.uk/free/' }
if ($missing.Count) { Invoke-GitHub PATCH "/repos/$org/$path" $missing | Out-Null }
$liveTopics = @($live.topics | Where-Object { $_ })
$newTopics = @($githubTopics | Where-Object { $liveTopics -notcontains $_ })
if ($newTopics) { Invoke-GitHub PUT "/repos/$org/$path/topics" @{ names = @(($liveTopics + $newTopics) | Sort-Object -Unique) } | Out-Null }
if ($missing.Count -or $newTopics) { Write-Host '  Missing description, website or topics added.' -ForegroundColor Green }
else { Write-Host '  Description, website and topics already set.' -ForegroundColor DarkGray }

$existingRulesets = @(Invoke-GitHub GET "/repos/$org/$path/rulesets" | ForEach-Object { $_.name })
foreach ($file in $rulesetFiles) {
    $name = ($rulesets[$file] | ConvertFrom-Json).name
    if ($existingRulesets -contains $name) { Write-Host "  Ruleset already there: $name" -ForegroundColor DarkGray; continue }
    Invoke-GitHub POST "/repos/$org/$path/rulesets" $rulesets[$file] | Out-Null
    Write-Host "  Ruleset added: $name" -ForegroundColor Green
}

# --- Badge ----------------------------------------------------------------------------------------

$badges = @(Invoke-GitLab GET "/projects/$($project.id)/badges")
if (-not ($badges | Where-Object { $_.kind -eq 'project' -and $_.name -eq 'GitHub' })) {
    Invoke-GitLab POST "/projects/$($project.id)/badges" @{
        name = 'GitHub'; link_url = $githubUrl
        image_url = "https://img.shields.io/github/v/release/$org/$path"
    } | Out-Null
    Write-Host '  GitHub badge added.' -ForegroundColor Green
}

# --- Mirror ---------------------------------------------------------------------------------------

# SSH as git@github.com, checked against GitHub's published host keys, using a key GitLab makes for this mirror
# alone. It never force-pushes (keep divergent refs) and mirrors every branch and tag, so a v* tag on GitLab runs
# the GitHub release workflow.
$mirrorUrl = "github.com/$org/$path.git"
$mirror = @(Invoke-GitLab GET "/projects/$($project.id)/remote_mirrors") | Where-Object { $_.url -like "*$mirrorUrl" } | Select-Object -First 1
if ($mirror) {
    Write-Host '  Push mirror already exists.' -ForegroundColor DarkGray
} else {
    $hostKeys = @((Invoke-RestMethod -Uri 'https://api.github.com/meta' -Headers @{ 'User-Agent' = 'Pigeon-Studios-Tools' }).ssh_keys | ForEach-Object { "github.com $_" })
    $mirror = Invoke-GitLab POST "/projects/$($project.id)/remote_mirrors" @{
        url = "ssh://git@$mirrorUrl"; auth_method = 'ssh_public_key'; host_keys = $hostKeys
        enabled = $true; keep_divergent_refs = $true; only_protected_branches = $false
    }
    Write-Host '  Push mirror created.' -ForegroundColor Green
}

$groupPath = $project.namespace.full_path -replace "^$gitlabGroup/", ''
$keyTitle = "GitLab push mirror ($groupPath/$path)"
$mirrorKey = (Invoke-GitLab GET "/projects/$($project.id)/remote_mirrors/$($mirror.id)/public_key").public_key
$deployKeys = @(Invoke-GitHub GET "/repos/$org/$path/keys")
if ($deployKeys | Where-Object { $_.title -eq $keyTitle -or $_.key -eq (($mirrorKey -split ' ')[0..1] -join ' ') }) {
    Write-Host '  Deploy key already there.' -ForegroundColor DarkGray
} else {
    Invoke-GitHub POST "/repos/$org/$path/keys" @{ title = $keyTitle; key = $mirrorKey; read_only = $false } | Out-Null
    Write-Host '  Deploy key added, with write access.' -ForegroundColor Green
}

Invoke-GitLab POST "/projects/$($project.id)/remote_mirrors/$($mirror.id)/sync" | Out-Null
$state = $null
for ($i = 0; $i -lt 24; $i++) {
    Start-Sleep -Seconds 5
    $state = Invoke-GitLab GET "/projects/$($project.id)/remote_mirrors/$($mirror.id)"
    if ($state.update_status -in 'finished', 'failed') { break }
}
if ($state.update_status -ne 'finished') {
    throw "The mirror reported '$($state.update_status)'$(if ($state.last_error) { ": $($state.last_error)" }). Check Settings -> Repository -> Mirroring repositories on GitLab, then run this again."
}
Write-Host '  Mirror pushed to GitHub.' -ForegroundColor Green

Write-Host ''
Write-Host "$path is public: $githubUrl" -ForegroundColor Cyan
Write-Host "Next: .\tools\Release-PigeonProject.ps1 -Slug $Slug -Bump minor (or -Version 1.0.0)"
