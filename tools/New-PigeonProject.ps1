<#
.SYNOPSIS
    Starts a new Pigeon Studios project: the folder, the standard files, CI, the first commit and a private GitLab
    project. Publish-PigeonProject.ps1 makes a free project public when it's ready, and
    Release-PigeonProject.ps1 releases it.

.DESCRIPTION
    Works in an empty folder, or in one where the resource is already written: files that exist are never
    overwritten. It's safe to run again: each step looks first and only does what's missing.

    Before changing anything, even with -DryRun, it checks that the update checker can be downloaded and, with a
    GitLab token, that the token works, has the access it needs and isn't near its expiry, and that SSH to GitLab
    works.

    1. Works out the names: the GitLab area, the path (pg-<slug> for paid resources, pigeon-<slug> for free
       FiveM resources), the local folder under D:\PigeonStudios\Repos and the version registry slug.
    2. Copies the standard files with New-PigeonRepo.ps1 (-Platform GitHub for free projects, which use the
       organisation's shared policies there, and -Platform GitLab for the rest).
    3. For FiveM resources, writes a starting fxmanifest.lua with version 0.1.0 and the registry slug, and
       copies the update checker from Pigeon Versions to server/version_check.lua.
    4. Writes .gitlab-ci.yml with the shared checks and release jobs, keeps CI files out of release zips and,
       for free FiveM resources, writes the GitHub CI and release workflows.
    5. Makes the first commit (as Pigeon) and points origin at GitLab.
    6. With a GitLab token (Set-PigeonToken.ps1): creates the private GitLab project with the studio's settings
       (description, topics, features off, protected v* tags, the icon given with -Icon) and pushes. Without one,
       it stops before pushing and prints how to finish.

    It then lists what's left to do by hand.

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
    One sentence for the README and the descriptions, without the product name or "Paid"/"Free".

.PARAMETER Topics
    Extra topics for GitLab and GitHub, such as "roleplay", "standalone", "qbox" or "nodejs". The website
    reads frameworks from the GitHub topics (standalone, qbox, qbcore, esx). The kind and platform topics,
    and pigeonstudios-release on GitHub, are added for you.

.PARAMETER Icon
    A 384 px PNG of the project's icon (from the handbook's brand/icons) to upload as the GitLab avatar.

.PARAMETER Folder
    Use another local folder instead of the usual one under D:\PigeonStudios\Repos (for trying the script out).

.PARAMETER DryRun
    Print what would happen and change nothing.

.EXAMPLE
    .\tools\New-PigeonProject.ps1 -Name 'Pigeon Notes' -Slug notes -Kind Free -Description 'Sticky notes players can leave around the map.' -Topics roleplay, standalone -Icon D:\icons\pigeon-notes.png

.EXAMPLE
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
    [string] $Icon,
    [string] $Folder,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PigeonCommon.ps1')
$standards = Split-Path -Parent $PSScriptRoot
$ciTemplatesRef = 'v1.4.0'
$reposRoot = 'D:\PigeonStudios\Repos'

# --- 1. Names -------------------------------------------------------------------------------------

if ($Kind -eq 'Paid') { $Type = 'FiveM' }
if ($Kind -eq 'Internal' -and $Type -eq 'FiveM') { throw 'Internal projects are General: use -Type General with -Area.' }
if ($Type -eq 'General' -and -not $Area) { throw 'A General project needs -Area Bots, Tools or Web.' }
if ($Icon -and -not (Test-Path -LiteralPath $Icon)) { throw "The icon $Icon doesn't exist." }

switch ("$Kind/$Type") {
    'Paid/FiveM'       { $path = "pg-$Slug";     $namespace = 'pigeon-studios/fivem/dev-releases' }
    'Free/FiveM'       { $path = "pigeon-$Slug"; $namespace = 'pigeon-studios/fivem/releases/github' }
    'Free/General'     { $path = $Slug;          $namespace = "pigeon-studios/$($Area.ToLower())" }
    'Internal/General' { $path = $Slug;          $namespace = "pigeon-studios/$($Area.ToLower())" }
}
# Local folders mirror the GitLab layout: D:\PigeonStudios\Repos\fivem\releases\github\pigeon-dice.
$groupPath = $namespace -replace '^pigeon-studios/', ''
$localFolder = Join-Path $reposRoot (Join-Path ($groupPath -replace '/', '\') $path)
if ($Folder) { $localFolder = $Folder }
$releaseKind = $Kind.ToLower()
$gitlabUrl = "https://gitlab.com/$namespace/$path"
$githubUrl = if ($Kind -eq 'Free') { "https://github.com/$org/$path" } else { $null }
$existingFolder = Test-Path -LiteralPath $localFolder
$suffix = switch ($Kind) {
    'Paid'     { 'Paid, on Tebex. Full unescrowed source.' }
    'Free'     { 'Free, on GitHub.' }
    'Internal' { 'Internal.' }
}
# "Shrike: a dash-mounted radar detector…": lower-case after the colon, unless it starts with a name like "GTA".
$sentence = $Description.TrimEnd('.')
if ($sentence -cmatch '^[A-Z]([a-z]|\s)') { $sentence = $sentence.Substring(0, 1).ToLower() + $sentence.Substring(1) }
$gitlabDescription = "${Name}: $sentence. $suffix"
$allTopics = @($Topics | ForEach-Object { $_.ToLower() })
if ($Type -eq 'FiveM') { $allTopics += 'fivem', 'lua' }
$allTopics += switch ($Kind) { 'Paid' { 'paid', 'tebex' } 'Free' { 'free', 'github' } 'Internal' { 'internal' } }
$allTopics = @($allTopics | Sort-Object -Unique)

Write-Host ''
Write-Host "  Product name      $Name"
Write-Host "  GitLab project    $gitlabUrl"
Write-Host "  Local folder      $localFolder$(if ($existingFolder) { '  (exists: its files are kept)' })"
if ($Type -eq 'FiveM') { Write-Host "  Resource folder   $path  (registry slug '$path')" }
if ($Kind -eq 'Paid') { Write-Host "  Cfx.re asset      PS - $Name" }
Write-Host "  Description       $gitlabDescription"
Write-Host "  Topics            $($allTopics -join ', ')"
if ($Icon) { Write-Host "  Icon              $Icon" }
if ($githubUrl) { Write-Host "  GitHub            $githubUrl  (not until Publish-PigeonProject.ps1)" }
Write-Host "  Releases          $releaseKind"
Write-Host ''


# --- Checks before anything changes ---------------------------------------------------------------

# The master copy of the update checker, kept byte for byte: every resource ships the identical file.
$checkerBytes = $null
if ($Type -eq 'FiveM') {
    $checkerUrl = "https://raw.githubusercontent.com/$org/pigeon-versions/main/checker/version_check.lua"
    $checkerBytes = (Invoke-WebRequest -Uri $checkerUrl -UseBasicParsing).RawContentStream.ToArray()
    if ([System.Text.Encoding]::UTF8.GetString($checkerBytes) -notmatch 'CHECKER_VERSION') { throw "$checkerUrl isn't the update checker." }
}

if ($gitlabToken) {
    Assert-GitLabToken
    if ((Get-Url "$api/namespaces/$([uri]::EscapeDataString($namespace))" $headers).Status -ne 200) { throw "The GitLab token can't see the group $namespace." }
    if (-not (Test-Git ls-remote --heads git@gitlab.com:pigeon-studios/repo-standards.git main)) { throw "Can't reach GitLab over SSH, so the first push would fail. Check the key in ~/.ssh (handbook: Working locally)." }
}

if ($DryRun) { Write-Host 'Dry run: nothing changed.' -ForegroundColor Yellow; return }

# --- 2. Standard files ----------------------------------------------------------------------------

# Free projects are read on GitHub, where the organisation's .github repository supplies the policies and
# issue forms, so they get the GitHub set like the released free repositories. GitLab-only projects carry
# their own copies, because GitLab Free has no shared defaults.
$platform = if ($Kind -eq 'Free') { 'GitHub' } else { 'GitLab' }
& (Join-Path $PSScriptRoot 'New-PigeonRepo.ps1') -Path $localFolder -Kind $Kind -Platform $platform -Type $Type -Name $Name -Folder $path -Description $Description

function Write-Text([string] $file, [string] $text) {
    $target = Join-Path $localFolder $file
    if (Test-Path -LiteralPath $target) { Write-Host "  keep   $file" -ForegroundColor DarkGray; return }
    $directory = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory | Out-Null }
    $text = $text.Replace("`r`n", "`n")
    if (-not $text.EndsWith("`n")) { $text += "`n" }
    [System.IO.File]::WriteAllText($target, $text, $utf8)
    Write-Host "  write  $file" -ForegroundColor Green
}

# Nothing is released yet: drop the template's 1.0.0 section and point the links at the commits.
$changelog = Join-Path $localFolder 'CHANGELOG.md'
$text = [System.IO.File]::ReadAllText($changelog, $utf8)
if ($text -match '\{\{RELEASE_DATE\}\}') {
    $text = [regex]::Replace($text, '(?s)## \[1\.0\.0\] - \{\{RELEASE_DATE\}\}.*?(?=<!--)', '')
    $history = if ($githubUrl) { "$githubUrl/commits/main" } else { "$gitlabUrl/-/commits/main" }
    $text = [regex]::Replace($text, '(?m)^\[Unreleased\]: .*$', "[Unreleased]: $history")
    $text = [regex]::Replace($text, '(?m)^\[1\.0\.0\]: .*\r?\n?', '')
    [System.IO.File]::WriteAllText($changelog, $text, $utf8)
    Write-Host '  edit   CHANGELOG.md (nothing released yet)' -ForegroundColor Green
}

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

-- Pigeon Studios version registry entry, read by server/version_check.lua.
pigeon_slug '$path'

shared_scripts {
}

client_scripts {
}

server_scripts {
    'server/version_check.lua',
}
"@
    if (-not (Test-Path -LiteralPath (Join-Path $localFolder 'server\version_check.lua'))) {
        New-Item -ItemType Directory -Force -Path (Join-Path $localFolder 'server') | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $localFolder 'server\version_check.lua'), $checkerBytes)
        Write-Host '  write  server/version_check.lua (the update checker, from Pigeon Versions)' -ForegroundColor Green
    }
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
$(if ($Kind -eq 'Free') { "`n# free: once a tag passes and its GitHub release is out, publish to the registry and GitHub Discussions." })
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
    $text = $text.TrimEnd() + "`n`n# Development files, not needed on a server.`ntests/           export-ignore`n.gitlab-ci.yml   export-ignore`n.gitleaks.toml   export-ignore`n"
    [System.IO.File]::WriteAllText($attributes, $text, $utf8)
    Write-Host '  edit   .gitattributes (tests and CI files left out of release zips)' -ForegroundColor Green
}

# Free FiveM resources are released on GitHub: CI checks the Lua compiles, and a v* tag (mirrored from
# GitLab) builds <path>.zip with git archive and publishes the release with the CHANGELOG section as notes.
if ($Kind -eq 'Free' -and $Type -eq 'FiveM') {
    Write-Text '.github/workflows/ci.yml' @'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  checks:
    name: Checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Lua 5.4
        run: sudo apt-get update -qq && sudo apt-get install -y -qq lua5.4

      - name: Check every Lua file compiles
        run: |
          for file in $(git ls-files '*.lua'); do
            luac5.4 -p "$file" || exit 1
          done

      - name: Manifest version matches the latest changelog entry
        run: |
          manifest=$(sed -n "s/^version '\(.*\)'$/\1/p" fxmanifest.lua)
          changelog=$(perl -0pe 's/<!--.*?-->//gs' CHANGELOG.md | grep -m1 -oP '^## \[\K[0-9][^]]*' || true)
          echo "fxmanifest.lua: $manifest  CHANGELOG.md: ${changelog:-nothing released yet}"
          [ -z "$changelog" ] || [ "$manifest" = "$changelog" ]
'@
    Write-Text '.github/workflows/release.yml' (@'
name: Release

# Push a tag such as v1.0.0 to publish a release. The tag must match the version in fxmanifest.lua,
# and CHANGELOG.md must have a section for it; its text becomes the release notes.

on:
  push:
    tags: ['v*.*.*']

permissions:
  contents: write

jobs:
  release:
    name: Publish release
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Lua 5.4
        run: sudo apt-get update -qq && sudo apt-get install -y -qq lua5.4

      - name: Check every Lua file compiles
        run: |
          for file in $(git ls-files '*.lua'); do
            luac5.4 -p "$file" || exit 1
          done

      - name: Check the tag matches fxmanifest.lua
        run: |
          manifest=$(sed -n "s/^version '\(.*\)'$/\1/p" fxmanifest.lua)
          [ "v$manifest" = "$GITHUB_REF_NAME" ] || { echo "Tag $GITHUB_REF_NAME doesn't match fxmanifest.lua version $manifest"; exit 1; }

      - name: Extract release notes from CHANGELOG.md
        run: |
          version="${GITHUB_REF_NAME#v}"
          perl -0pe 's/<!--.*?-->//gs' CHANGELOG.md | awk -v v="$version" '
            index($0, "## [" v "]") == 1 { found = 1; next }
            found && /^## \[/ { exit }
            found && /^\[.*\]: / { exit }
            found { print }
          ' > notes.md
          [ -s notes.md ] || { echo "No CHANGELOG.md section for $version"; exit 1; }

      - name: Build {{PATH}}.zip
        run: git archive --format=zip --prefix={{PATH}}/ -o {{PATH}}.zip "$GITHUB_REF_NAME"

      - name: Publish
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh release create "$GITHUB_REF_NAME" {{PATH}}.zip --title "{{NAME}} $GITHUB_REF_NAME" --notes-file notes.md
'@).Replace('{{PATH}}', $path).Replace('{{NAME}}', $Name)
}

# --- 5. First commit ------------------------------------------------------------------------------

Push-Location $localFolder
try {
    if (-not (Test-Path -LiteralPath (Join-Path $localFolder '.git'))) { Invoke-Git init --quiet -b main }
    if (-not (Test-Git rev-parse --verify --quiet HEAD)) {
        Invoke-Git add -A
        Invoke-Git -c user.name=Pigeon -c user.email=pigeonstudiosllc@gmail.com commit --quiet -m "Start $Name"
        Write-Host '  First commit made.' -ForegroundColor Green
    } else {
        Write-Host '  Already has commits; anything new is yours to commit.' -ForegroundColor DarkGray
    }
    $remotes = @(& git remote)
    if ($remotes -notcontains 'origin') { Invoke-Git remote add origin "git@gitlab.com:$namespace/$path.git" }
    if ($Kind -eq 'Free' -and $remotes -notcontains 'github') {
        # Free projects are pushed to GitLab only; GitLab mirrors them to GitHub.
        Invoke-Git remote add github "https://github.com/$org/$path.git"
        Invoke-Git remote set-url --push github 'DISABLED: push to GitLab (origin); it mirrors to GitHub'
    }
} finally { Pop-Location }

# --- 6. GitLab project ----------------------------------------------------------------------------

$todo = New-Object System.Collections.Generic.List[string]
$project = $null

if ($gitlabToken) {
    $found = Get-Url "$api/projects/$([uri]::EscapeDataString("$namespace/$path"))" $headers
    if ($found.Status -eq 200) {
        $project = $found.Content | ConvertFrom-Json
        Write-Host "  GitLab project already exists: $($project.web_url)" -ForegroundColor DarkGray
    } else {
        $ns = Invoke-GitLab GET "/namespaces/$([uri]::EscapeDataString($namespace))"
        $project = Invoke-GitLab POST '/projects' @{
            name = $Name; path = $path; namespace_id = $ns.id; description = $gitlabDescription; topics = $allTopics
            visibility = 'private'; initialize_with_readme = $false
            wiki_access_level = 'disabled'; snippets_access_level = 'disabled'; pages_access_level = 'disabled'
            container_registry_access_level = 'disabled'; package_registry_access_level = 'disabled'
            model_experiments_access_level = 'private'; model_registry_access_level = 'private'
        }
        Write-Host "  GitLab project created: $($project.web_url)" -ForegroundColor Green
    }

    if (-not (@(Invoke-GitLab GET "/projects/$($project.id)/protected_tags") | Where-Object { $_.name -eq 'v*' })) {
        Invoke-GitLab POST "/projects/$($project.id)/protected_tags" @{ name = 'v*'; create_access_level = 40 } | Out-Null
        Write-Host '  v* tags protected (Maintainers create, nobody moves or deletes).' -ForegroundColor Green
    }

    if ($Icon) {
        # Invoke-RestMethod in Windows PowerShell can't send multipart forms, so curl.exe uploads the avatar.
        $status = & curl.exe --silent --output NUL --write-out '%{http_code}' --request PUT --header "PRIVATE-TOKEN: $gitlabToken" --form "avatar=@$Icon" "$api/projects/$($project.id)"
        if ($status -eq '200') { Write-Host '  Icon uploaded.' -ForegroundColor Green }
        else { $todo.Add("Icon: the upload failed (HTTP $status). Upload $Icon in the GitLab project's Settings -> General -> Project avatar.") }
    }

    Push-Location $localFolder
    try { Invoke-Git push --quiet -u origin main } finally { Pop-Location }
    Write-Host '  Pushed. The first pipeline runs the shared checks.' -ForegroundColor Green
} else {
    $todo.Add("Create the GitLab project: save a token with .\tools\Set-PigeonToken.ps1 -Service GitLab and run this again.")
}

# --- What's left ----------------------------------------------------------------------------------

if (-not $Icon) {
    $todo.Add("Icon: add a glyph for '$path' to the handbook's brand/tools/make-icons.js, run it, and upload the PNG to the GitLab project (handbook: Brand and icons), or pass -Icon next time.")
}
$manifestFile = Join-Path $localFolder 'fxmanifest.lua'
if ((Test-Path -LiteralPath $manifestFile) -and [System.IO.File]::ReadAllText($manifestFile, $utf8) -notmatch 'version_check\.lua') {
    $todo.Add("Update checker: add 'server/version_check.lua' to server_scripts in fxmanifest.lua.")
}
if ((Test-Path -LiteralPath $manifestFile) -and [System.IO.File]::ReadAllText($manifestFile, $utf8) -notmatch '(?m)^\s*pigeon_slug') {
    $todo.Add("Update checker: add pigeon_slug '$path' to fxmanifest.lua.")
}
$images = [regex]::Matches([System.IO.File]::ReadAllText((Join-Path $localFolder 'README.md'), $utf8), '<img src="(?!https?:)([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
if ($images) {
    $todo.Add("Images: the README shows $($images -join ' and '), which don't exist yet. The links check warns until the first tag, which fails without them. Banners are drawn as in the handbook's Brand and icons.")
}
if ($Kind -eq 'Free') {
    if ($Type -ne 'FiveM') {
        $todo.Add('GitHub workflows: copy .github/workflows/ci.yml and release.yml from an existing General free project (Monday to Discord), so tags build the release on GitHub.')
    }
    $todo.Add("When it's ready to be seen: .\tools\Publish-PigeonProject.ps1 -Slug $Slug. Then release it with .\tools\Release-PigeonProject.ps1 -Slug $Slug -Version 1.0.0.")
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
