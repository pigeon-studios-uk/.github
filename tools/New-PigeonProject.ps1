<#
.SYNOPSIS
    Starts a new Pigeon Studios project: the folder, the standard files, CI, the first commit and the GitLab project.

.DESCRIPTION
    Does every step of the handbook's new-project checklist that can be done from the PC:

    1. Works out the names: the GitLab area, the path (pg-<slug> for paid resources, pigeon-<slug> for free
       FiveM resources), the local folder under D:\Git and the version registry slug.
    2. Copies the standard files with New-PigeonRepo.ps1 (-Platform GitLab).
    3. For FiveM resources, writes a starting fxmanifest.lua with version 0.1.0 and the registry slug.
    4. Writes .gitlab-ci.yml with the shared checks and release jobs, and keeps CI files out of release zips.
    5. Makes the first commit (as Pigeon) and points origin at GitLab.
    6. With a GitLab token in $env:GITLAB_TOKEN: creates the GitLab project with the studio's settings
       (description, topics, features off, protected v* tags, a GitHub badge for free projects) and pushes.
       Without one, it stops before pushing and prints how to finish.

    It then lists what's left to do by hand: the icon, and for free projects the GitHub repository and mirror.
    The version registry entry is made by the first release's publish job.

.PARAMETER Name
    The product name, as people read it: "Shrike", "Pigeon Dice", "ROCKDOVE Vending".

.PARAMETER Slug
    Short lower-case name, without pg- or pigeon-: "shrike", "dice". The paths are built from it.

.PARAMETER Kind
    Paid (FiveM, Dev Releases), Free (on GitHub) or Internal.

.PARAMETER Type
    FiveM (default) or General (a bot, tool, library or website component).

.PARAMETER Area
    Where a General or Internal project goes on GitLab: Bots, Tools or Web. FiveM projects don't need it.

.PARAMETER Description
    One sentence for the README and the GitLab description, without the product name or "Paid"/"Free".

.PARAMETER Topics
    Extra GitLab topics, such as "systems-scripts" or "nodejs". The kind and platform topics are added for you.

.PARAMETER Folder
    Use another local folder instead of the usual one under D:\Git (for trying the script out).

.PARAMETER DryRun
    Print what would happen and change nothing.

.EXAMPLE
    $env:GITLAB_TOKEN = '<a personal access token with the api scope>'
    .\tools\New-PigeonProject.ps1 -Name 'Kingfisher' -Slug kingfisher -Kind Paid -Description 'A fishing job with boats, rods and a fish market.' -Topics jobs

.EXAMPLE
    .\tools\New-PigeonProject.ps1 -Name 'Pigeon Notes' -Slug notes -Kind Free -Description 'Sticky notes players can leave around the map.' -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Name,
    [Parameter(Mandatory)] [ValidatePattern('^[a-z0-9][a-z0-9-]{1,40}$')] [string] $Slug,
    [Parameter(Mandatory)] [ValidateSet('Paid', 'Free', 'Internal')] [string] $Kind,
    [ValidateSet('FiveM', 'General')] [string] $Type = 'FiveM',
    [ValidateSet('Bots', 'Tools', 'Web')] [string] $Area,
    [Parameter(Mandatory)] [string] $Description,
    [string[]] $Topics = @(),
    [string] $Folder,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$standards = Split-Path -Parent $PSScriptRoot
$ciTemplatesRef = 'v1.2.0'
$org = 'pigeon-studios-uk'

# --- 1. Names -------------------------------------------------------------------------------------

if ($Kind -eq 'Paid') { $Type = 'FiveM' }
if ($Kind -eq 'Internal' -and $Type -eq 'FiveM') { throw 'Internal projects are General: use -Type General with -Area.' }
if ($Type -eq 'General' -and -not $Area) { throw 'A General project needs -Area Bots, Tools or Web.' }

switch ("$Kind/$Type") {
    'Paid/FiveM'       { $path = "pg-$Slug";     $namespace = 'pigeon-studios/fivem/dev-releases';   $localFolder = "D:\Git\GitLabs\$path" }
    'Free/FiveM'       { $path = "pigeon-$Slug"; $namespace = 'pigeon-studios/fivem/releases/github'; $localFolder = "D:\Git\GitHub\$path" }
    'Free/General'     { $path = $Slug;          $namespace = "pigeon-studios/$($Area.ToLower())";   $localFolder = "D:\Git\GitHub\$path" }
    'Internal/General' { $path = $Slug;          $namespace = "pigeon-studios/$($Area.ToLower())";   $localFolder = "D:\Git\GitLabs\$path" }
}
if ($Folder) { $localFolder = $Folder }
$releaseKind = $Kind.ToLower()
$gitlabUrl = "https://gitlab.com/$namespace/$path"
$githubUrl = if ($Kind -eq 'Free') { "https://github.com/$org/$path" } else { $null }
$suffix = switch ($Kind) {
    'Paid'     { 'Paid, on Tebex. Full unescrowed source.' }
    'Free'     { 'Free, on GitHub.' }
    'Internal' { 'Internal.' }
}
# "Shrike: a dash-mounted radar detector…": lower-case after the colon, unless it starts with a name like "GTA".
$sentence = $Description.TrimEnd('.')
if ($sentence -cmatch '^[A-Z][a-z]') { $sentence = $sentence.Substring(0, 1).ToLower() + $sentence.Substring(1) }
$gitlabDescription = "${Name}: $sentence. $suffix"
$allTopics = @($Topics)
if ($Type -eq 'FiveM') { $allTopics += 'fivem', 'lua' }
$allTopics += switch ($Kind) { 'Paid' { 'paid', 'tebex' } 'Free' { 'free', 'github' } 'Internal' { 'internal' } }
$allTopics = $allTopics | Sort-Object -Unique

Write-Host ''
Write-Host "  Product name      $Name"
Write-Host "  GitLab project    $gitlabUrl"
Write-Host "  Local folder      $localFolder"
if ($Type -eq 'FiveM') { Write-Host "  Resource folder   $path  (registry slug '$path')" }
if ($Kind -eq 'Paid') { Write-Host "  Cfx.re asset      PS - $Name" }
if ($githubUrl) { Write-Host "  GitHub            $githubUrl" }
Write-Host "  Description       $gitlabDescription"
Write-Host "  Topics            $($allTopics -join ', ')"
Write-Host "  Releases          $releaseKind"
Write-Host ''

if (Test-Path -LiteralPath $localFolder) { throw "$localFolder already exists. Choose another slug, or set up the existing folder by hand." }
if ($DryRun) { Write-Host 'Dry run: nothing changed.' -ForegroundColor Yellow; return }

# --- 2. Standard files ----------------------------------------------------------------------------

& (Join-Path $PSScriptRoot 'New-PigeonRepo.ps1') -Path $localFolder -Kind $Kind -Platform GitLab -Type $Type -Name $Name -Folder $path -Description $Description

$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Text([string] $file, [string] $text) {
    $target = Join-Path $localFolder $file
    $directory = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory | Out-Null }
    [System.IO.File]::WriteAllText($target, $text.Replace("`r`n", "`n"), $utf8)
    Write-Host "  write  $file" -ForegroundColor Green
}

# Nothing is released yet: drop the template's 1.0.0 section and point the links at the commits.
$changelog = Join-Path $localFolder 'CHANGELOG.md'
$text = [System.IO.File]::ReadAllText($changelog, $utf8)
$text = [regex]::Replace($text, '(?s)## \[1\.0\.0\] - \{\{RELEASE_DATE\}\}.*?(?=<!--)', '')
$history = if ($githubUrl) { "$githubUrl/commits/main" } else { "$gitlabUrl/-/commits/main" }
$text = [regex]::Replace($text, '(?m)^\[Unreleased\]: .*$', "[Unreleased]: $history")
$text = [regex]::Replace($text, '(?m)^\[1\.0\.0\]: .*\r?\n?', '')
[System.IO.File]::WriteAllText($changelog, $text, $utf8)
Write-Host '  edit   CHANGELOG.md (nothing released yet)' -ForegroundColor Green

# --- 3. fxmanifest.lua ----------------------------------------------------------------------------

if ($Type -eq 'FiveM') {
    Write-Text 'fxmanifest.lua' @"
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name '$path'
author 'Pigeon Studios'
description '$($Description.Replace("'", "\'"))'
version '0.1.0'
repository '$(if ($githubUrl) { $githubUrl } else { 'https://pigeonstudios.co.uk' })'
pigeon_slug '$path'

shared_scripts {
}

client_scripts {
}

server_scripts {
}
"@
}

# Bots and tools are Node.js projects; package.json carries their version for the shared checks.
if ($Type -eq 'General') {
    # Written out by hand: Windows PowerShell's ConvertTo-Json escapes apostrophes and indents oddly.
    $jsonDescription = $Description.Replace('\', '\\').Replace('"', '\"')
    Write-Text 'package.json' @"
{
  "name": "$path",
  "version": "0.1.0",
  "description": "$jsonDescription",
  "private": true,
  "license": "SEE LICENSE IN LICENSE.md",
  "author": "Pigeon Studios (https://pigeonstudios.co.uk)",
  "type": "module",
  "engines": {
    "node": ">=22"
  },
  "scripts": {
    "test": "node --test"
  }
}

"@
}

# --- 4. CI ----------------------------------------------------------------------------------------

Write-Text '.gitlab-ci.yml' @"
# The shared checks (version, CHANGELOG, Lua syntax, README links, secrets) and release jobs:
# https://gitlab.com/pigeon-studios/tools/ci-templates
include:
  - project: pigeon-studios/tools/ci-templates
    ref: $ciTemplatesRef
    file:
      - templates/checks.yml
      - templates/release.yml

variables:
  PS_RELEASE_KIND: $releaseKind

workflow:
  rules:
    - if: `$CI_PIPELINE_SOURCE == "merge_request_event"
    - if: `$CI_COMMIT_BRANCH == `$CI_DEFAULT_BRANCH
    - if: `$CI_COMMIT_TAG
"@

$attributes = Join-Path $localFolder '.gitattributes'
$text = [System.IO.File]::ReadAllText($attributes, $utf8)
if ($text -notmatch '(?m)^\.gitlab-ci\.yml\s') {
    $text = $text.TrimEnd() + "`n.gitlab-ci.yml    export-ignore`n"
    [System.IO.File]::WriteAllText($attributes, $text, $utf8)
    Write-Host '  edit   .gitattributes (.gitlab-ci.yml left out of release zips)' -ForegroundColor Green
}

# --- 5. First commit ------------------------------------------------------------------------------

Push-Location $localFolder
try {
    git init --quiet -b main
    git add -A
    git -c user.name=Pigeon -c user.email=pigeonstudiosllc@gmail.com commit --quiet -m "Start $Name"
    git remote add origin "git@gitlab.com:$namespace/$path.git"
    if ($Kind -eq 'Free') {
        # Free projects are pushed to GitLab only; GitLab mirrors them to GitHub.
        git remote add github "https://github.com/$org/$path.git"
        git remote set-url --push github 'DISABLED: push to GitLab (origin); it mirrors to GitHub'
    }
} finally { Pop-Location }
Write-Host '  First commit made.' -ForegroundColor Green

# --- 6. GitLab project ----------------------------------------------------------------------------

$todo = New-Object System.Collections.Generic.List[string]

if ($env:GITLAB_TOKEN) {
    $api = 'https://gitlab.com/api/v4'
    $headers = @{ 'PRIVATE-TOKEN' = $env:GITLAB_TOKEN }
    function Invoke-GitLab([string] $method, [string] $uri, $body) {
        $json = if ($body) { $body | ConvertTo-Json -Depth 5 } else { $null }
        Invoke-RestMethod -Method $method -Uri "$api$uri" -Headers $headers -ContentType 'application/json' -Body $json
    }

    $ns = Invoke-GitLab GET "/namespaces/$([uri]::EscapeDataString($namespace))"
    $project = Invoke-GitLab POST '/projects' @{
        name = $Name; path = $path; namespace_id = $ns.id; description = $gitlabDescription; topics = $allTopics
        visibility = 'private'; initialize_with_readme = $false
        wiki_access_level = 'disabled'; snippets_access_level = 'disabled'; pages_access_level = 'disabled'
        container_registry_access_level = 'disabled'; packages_enabled = $false
    }
    Write-Host "  GitLab project created: $($project.web_url)" -ForegroundColor Green

    Invoke-GitLab POST "/projects/$($project.id)/protected_tags" @{ name = 'v*'; create_access_level = 40 } | Out-Null
    Write-Host '  v* tags protected (Maintainers create, nobody moves or deletes).' -ForegroundColor Green

    if ($githubUrl) {
        Invoke-GitLab POST "/projects/$($project.id)/badges" @{
            name = 'GitHub'; link_url = $githubUrl
            image_url = "https://img.shields.io/badge/GitHub-$($path.Replace('-', '--'))-181717?logo=github"
        } | Out-Null
        Write-Host '  GitHub badge added.' -ForegroundColor Green
    }

    Push-Location $localFolder
    try { git push --quiet -u origin main } finally { Pop-Location }
    Write-Host '  Pushed. The first pipeline runs the shared checks.' -ForegroundColor Green
} else {
    $todo.Add("Create the GitLab project: set `$env:GITLAB_TOKEN and run this again on a fresh folder, or push (git push -u origin main) and set the description, topics, protected v* tags and settings by hand, as in the handbook's checklist.")
}

# --- What's left ----------------------------------------------------------------------------------

$todo.Add("Icon: add a glyph for '$path' to the handbook's brand/tools/make-icons.js, run it, and upload the PNG (handbook: Brand and icons).")
$images = [regex]::Matches([System.IO.File]::ReadAllText((Join-Path $localFolder 'README.md'), $utf8), '<img src="(?!https?:)([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
if ($images) {
    $todo.Add("Images: the README shows $($images -join ' and '), which don't exist yet, so the links check fails until they're added. Banners are drawn as in the handbook's Brand and icons.")
}
if ($Kind -eq 'Free') {
    $todo.Add("GitHub: create $githubUrl (public, empty), import the two rulesets from the handbook's github/rulesets/, add the deploy key and GitLab push mirror (handbook: GitHub), and the site webhook.")
    $todo.Add('GitHub release workflow: copy .github/workflows/release.yml (and ci.yml) from an existing free resource, so tags build the zip on GitHub.')
}
if ($Kind -eq 'Paid') {
    $todo.Add("Releases -> Tebex: create fivem/releases/tebex/$path when the first release ships, and the Cfx.re asset 'PS - $Name'.")
    $todo.Add("After the first release, add the Tebex store link to resources/$path.json in Pigeon Versions.")
}
$todo.Add('Fill in the README, CHANGELOG and docs placeholders listed above, then commit.')

Write-Host ''
Write-Host 'Still to do:' -ForegroundColor Cyan
$i = 1
foreach ($item in $todo) { Write-Host "  $i. $item"; $i++ }
