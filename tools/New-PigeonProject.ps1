<#
.SYNOPSIS
    Starts a new Pigeon Studios project: the folder, the standard files, CI, the first commit, the GitLab
    project and, for free projects, the GitHub repository and its mirror.

.DESCRIPTION
    Does every step of the handbook's new-project checklist that can be done from the PC. Before changing
    anything, even with -DryRun, it checks that the update checker can be downloaded and, for each token that
    is set, that the token works, has the access it needs and isn't near its expiry, that SSH to GitLab works,
    and that the GitLab project and GitHub repository don't exist yet.

    1. Works out the names: the GitLab area, the path (pg-<slug> for paid resources, pigeon-<slug> for free
       FiveM resources), the local folder under D:\PigeonStudios\Repos and the version registry slug.
    2. Copies the standard files with New-PigeonRepo.ps1 (-Platform GitHub for free projects, which use the
       organisation's shared policies there, and -Platform GitLab for the rest).
    3. For FiveM resources, writes a starting fxmanifest.lua with version 0.1.0 and the registry slug, and
       copies the update checker from Pigeon Versions to server/version_check.lua.
    4. Writes .gitlab-ci.yml with the shared checks and release jobs, keeps CI files out of release zips and,
       for free FiveM resources, writes the GitHub CI and release workflows.
    5. Makes the first commit (as Pigeon) and points origin at GitLab.
    6. With a GitLab token in $env:GITLAB_TOKEN: creates the GitLab project with the studio's settings
       (description, topics, features off, protected v* tags, a GitHub badge for free projects, the icon
       given with -Icon) and pushes. Without one, it stops before pushing and prints how to finish.
    7. For free projects, with a GitHub token in $env:GITHUB_TOKEN as well: creates the public GitHub
       repository (description, website, topics), imports the two rulesets from the handbook, creates the
       GitLab push mirror over SSH with GitHub's host keys, adds the mirror's key as a deploy key with write
       access, and pushes the mirror once to check it works.

    It then lists what's left to do by hand: the icon if -Icon wasn't given, the banner, and the lists of
    free resources in the handbook and Repo Standards, and the website's webhook. The version registry entry
    is added by the first release's publish job.

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

.PARAMETER Handbook
    The local handbook clone, for the GitHub rulesets. Defaults to D:\PigeonStudios\Repos\handbook.

.PARAMETER Folder
    Use another local folder instead of the usual one under D:\PigeonStudios\Repos (for trying the script out).

.PARAMETER DryRun
    Print what would happen and change nothing.

.EXAMPLE
    $env:GITLAB_TOKEN = '<GitLab personal access token, api scope>'
    $env:GITHUB_TOKEN = '<fine-grained token owned by pigeon-studios-uk: all repositories, Administration read and write>'
    .\tools\New-PigeonProject.ps1 -Name 'Pigeon Notes' -Slug notes -Kind Free -Description 'Sticky notes players can leave around the map.' -Topics roleplay, standalone -Icon D:\icons\pigeon-notes.png

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
    [string] $Icon,
    [string] $Handbook = 'D:\PigeonStudios\Repos\handbook',
    [string] $Folder,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$standards = Split-Path -Parent $PSScriptRoot
$ciTemplatesRef = 'v1.3.0'
$org = 'pigeon-studios-uk'
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

# GitHub matches the released free repositories: "<sentence>. Free.", the Free releases page as the website,
# and pigeonstudios-release, which marks our releases. fivem, free and github would only repeat the obvious.
$githubDescription = "$($Description.TrimEnd('.')). Free."
$githubTopics = @($Topics | ForEach-Object { $_.ToLower() })
if ($Type -eq 'FiveM') { $githubTopics += 'lua' }
$githubTopics = @(($githubTopics + 'pigeonstudios-release') | Sort-Object -Unique)
$githubSetup = $githubUrl -and $env:GITLAB_TOKEN -and $env:GITHUB_TOKEN

Write-Host ''
Write-Host "  Product name      $Name"
Write-Host "  GitLab project    $gitlabUrl"
Write-Host "  Local folder      $localFolder"
if ($Type -eq 'FiveM') { Write-Host "  Resource folder   $path  (registry slug '$path')" }
if ($Kind -eq 'Paid') { Write-Host "  Cfx.re asset      PS - $Name" }
Write-Host "  Description       $gitlabDescription"
Write-Host "  Topics            $($allTopics -join ', ')"
if ($Icon) { Write-Host "  Icon              $Icon" }
if ($githubUrl) {
    Write-Host "  GitHub            $githubUrl$(if (-not $githubSetup) { '  (set GITLAB_TOKEN and GITHUB_TOKEN to create it)' })"
    Write-Host "  GitHub about      $githubDescription"
    Write-Host "  GitHub topics     $($githubTopics -join ', ')"
}
Write-Host "  Releases          $releaseKind"
Write-Host ''

if (Test-Path -LiteralPath $localFolder) { throw "$localFolder already exists. Choose another slug, or set up the existing folder by hand." }
if ($githubSetup) {
    foreach ($file in 'protect-main.json', 'protect-release-tags.json') {
        if (-not (Test-Path -LiteralPath (Join-Path $Handbook "github\rulesets\$file"))) { throw "The handbook's github\rulesets\$file isn't in $Handbook. Clone the handbook or pass -Handbook." }
    }
}

# Bodies go as UTF-8 bytes: Windows PowerShell would otherwise send them in the ANSI code page. The comma
# returns the bytes as one array; without it PowerShell unrolls them into a list of numbers, which
# Invoke-RestMethod sends as text ("123 34 ...") and the API rejects as invalid JSON.
function ConvertTo-Body($body) {
    if ($null -eq $body) { return $null }
    $json = if ($body -is [string]) { $body } else { $body | ConvertTo-Json -Depth 10 }
    , [System.Text.Encoding]::UTF8.GetBytes($json)
}

$api = 'https://gitlab.com/api/v4'
$headers = @{ 'PRIVATE-TOKEN' = $env:GITLAB_TOKEN }
function Invoke-GitLab([string] $method, [string] $uri, $body) {
    Invoke-RestMethod -Method $method -Uri "$api$uri" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-Body $body)
}

$ghHeaders = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"; Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'New-PigeonProject'
}
function Invoke-GitHub([string] $method, [string] $uri, $body) {
    Invoke-RestMethod -Method $method -Uri "https://api.github.com$uri" -Headers $ghHeaders -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-Body $body)
}

# PowerShell carries on when a native command fails, so every git call checks its own exit code.
function Invoke-Git {
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $args failed with exit code $LASTEXITCODE." }
}

# A read-only request that reports a 4xx instead of stopping: its status, headers and body as text.
function Get-Url([string] $uri, [hashtable] $requestHeaders) {
    try {
        $response = Invoke-WebRequest -Uri $uri -Headers $requestHeaders -UseBasicParsing
        [pscustomobject]@{ Status = [int] $response.StatusCode; Headers = $response.Headers; Content = $response.Content }
    } catch [System.Net.WebException] {
        if (-not $_.Exception.Response) { throw "Couldn't reach ${uri}: $($_.Exception.Message)" }
        [pscustomobject]@{ Status = [int] $_.Exception.Response.StatusCode; Headers = @{}; Content = '' }
    }
}

function Show-TokenExpiry([string] $token, [string] $date) {
    if (-not $date) { Write-Host "  $token works and doesn't expire."; return }
    $days = ([datetime]::Parse($date.Substring(0, 10)) - (Get-Date).Date).Days
    if ($days -le 30) { Write-Host "  $token works, but expires on $($date.Substring(0, 10)), in $days days. Replace it soon." -ForegroundColor Yellow }
    else { Write-Host "  $token works, and expires on $($date.Substring(0, 10))." }
}

# --- Checks before anything changes ---------------------------------------------------------------

# The master copy of the update checker, kept byte for byte: every resource ships the identical file.
$checkerBytes = $null
if ($Type -eq 'FiveM') {
    $checkerUrl = "https://raw.githubusercontent.com/$org/pigeon-versions/main/checker/version_check.lua"
    $checkerBytes = (Invoke-WebRequest -Uri $checkerUrl -UseBasicParsing).RawContentStream.ToArray()
    if ([System.Text.Encoding]::UTF8.GetString($checkerBytes) -notmatch 'CHECKER_VERSION') { throw "$checkerUrl isn't the update checker." }
}

if ($env:GITLAB_TOKEN) {
    $self = Get-Url "$api/personal_access_tokens/self" $headers
    if ($self.Status -ne 200) { throw "GitLab refused GITLAB_TOKEN (HTTP $($self.Status)). It may have expired or been revoked; make a new one (handbook: Starting a new project)." }
    $tokenInfo = $self.Content | ConvertFrom-Json
    if ($tokenInfo.scopes -notcontains 'api') { throw "GITLAB_TOKEN has the scopes '$($tokenInfo.scopes -join ', ')'. It needs api." }
    Show-TokenExpiry 'GitLab token' $tokenInfo.expires_at

    if ((Get-Url "$api/namespaces/$([uri]::EscapeDataString($namespace))" $headers).Status -ne 200) { throw "GITLAB_TOKEN can't see the GitLab group $namespace." }
    $existing = (Get-Url "$api/projects/$([uri]::EscapeDataString("$namespace/$path"))" $headers).Status
    if ($existing -ne 404) { throw "$gitlabUrl already exists (HTTP $existing). Choose another slug." }

    & git ls-remote --heads git@gitlab.com:pigeon-studios/repo-standards.git main | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Can't reach GitLab over SSH, so the first push would fail. Check the key in ~/.ssh (handbook: Working locally)." }
}

if ($githubSetup) {
    # Deploy keys need Administration, which an unapproved or wrongly scoped token doesn't have.
    $keys = Get-Url "https://api.github.com/repos/$org/.github/keys" $ghHeaders
    if ($keys.Status -eq 401) { throw "GitHub refused GITHUB_TOKEN. It may have expired or been revoked; make a new one (handbook: Starting a new project)." }
    if ($keys.Status -ne 200) { throw "GITHUB_TOKEN can't administer $org (HTTP $($keys.Status)). It needs resource owner $org, all repositories and Administration read and write, and the organisation must have approved it." }
    Show-TokenExpiry 'GitHub token' $keys.Headers['github-authentication-token-expiration']

    $existing = (Get-Url "https://api.github.com/repos/$org/$path" $ghHeaders).Status
    if ($existing -ne 404) { throw "$githubUrl already exists (HTTP $existing). Choose another slug." }
}

if ($DryRun) { Write-Host 'Dry run: nothing changed.' -ForegroundColor Yellow; return }

# --- 2. Standard files ----------------------------------------------------------------------------

# Free projects are read on GitHub, where the organisation's .github repository supplies the policies and
# issue forms, so they get the GitHub set like the released free repositories. GitLab-only projects carry
# their own copies, because GitLab Free has no shared defaults.
$platform = if ($Kind -eq 'Free') { 'GitHub' } else { 'GitLab' }
& (Join-Path $PSScriptRoot 'New-PigeonRepo.ps1') -Path $localFolder -Kind $Kind -Platform $platform -Type $Type -Name $Name -Folder $path -Description $Description

$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Text([string] $file, [string] $text) {
    $target = Join-Path $localFolder $file
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
    New-Item -ItemType Directory -Path (Join-Path $localFolder 'server') | Out-Null
    [System.IO.File]::WriteAllBytes((Join-Path $localFolder 'server\version_check.lua'), $checkerBytes)
    Write-Host '  write  server/version_check.lua (the update checker, from Pigeon Versions)' -ForegroundColor Green
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
    Invoke-Git init --quiet -b main
    Invoke-Git add -A
    Invoke-Git -c user.name=Pigeon -c user.email=pigeonstudiosllc@gmail.com commit --quiet -m "Start $Name"
    Invoke-Git remote add origin "git@gitlab.com:$namespace/$path.git"
    if ($Kind -eq 'Free') {
        # Free projects are pushed to GitLab only; GitLab mirrors them to GitHub.
        Invoke-Git remote add github "https://github.com/$org/$path.git"
        Invoke-Git remote set-url --push github 'DISABLED: push to GitLab (origin); it mirrors to GitHub'
    }
} finally { Pop-Location }
Write-Host '  First commit made.' -ForegroundColor Green

# --- 6. GitLab project ----------------------------------------------------------------------------

$todo = New-Object System.Collections.Generic.List[string]
$project = $null

if ($env:GITLAB_TOKEN) {
    $ns = Invoke-GitLab GET "/namespaces/$([uri]::EscapeDataString($namespace))"
    $project = Invoke-GitLab POST '/projects' @{
        name = $Name; path = $path; namespace_id = $ns.id; description = $gitlabDescription; topics = $allTopics
        visibility = 'private'; initialize_with_readme = $false
        wiki_access_level = 'disabled'; snippets_access_level = 'disabled'; pages_access_level = 'disabled'
        container_registry_access_level = 'disabled'; package_registry_access_level = 'disabled'
        model_experiments_access_level = 'private'; model_registry_access_level = 'private'
    }
    Write-Host "  GitLab project created: $($project.web_url)" -ForegroundColor Green

    Invoke-GitLab POST "/projects/$($project.id)/protected_tags" @{ name = 'v*'; create_access_level = 40 } | Out-Null
    Write-Host '  v* tags protected (Maintainers create, nobody moves or deletes).' -ForegroundColor Green

    if ($githubUrl) {
        Invoke-GitLab POST "/projects/$($project.id)/badges" @{
            name = 'GitHub'; link_url = $githubUrl
            image_url = "https://img.shields.io/github/v/release/$org/$path"
        } | Out-Null
        Write-Host '  GitHub badge added.' -ForegroundColor Green
    }

    if ($Icon) {
        # Invoke-RestMethod in Windows PowerShell can't send multipart forms, so curl.exe uploads the avatar.
        $status = & curl.exe --silent --output NUL --write-out '%{http_code}' --request PUT --header "PRIVATE-TOKEN: $env:GITLAB_TOKEN" --form "avatar=@$Icon" "$api/projects/$($project.id)"
        if ($status -eq '200') { Write-Host '  Icon uploaded.' -ForegroundColor Green }
        else { $todo.Add("Icon: the upload failed (HTTP $status). Upload $Icon in the GitLab project's Settings -> General -> Project avatar.") }
    }

    Push-Location $localFolder
    try { Invoke-Git push --quiet -u origin main } finally { Pop-Location }
    Write-Host '  Pushed. The first pipeline runs the shared checks.' -ForegroundColor Green
} else {
    $todo.Add("Create the GitLab project: set `$env:GITLAB_TOKEN and run this again on a fresh folder, or push (git push -u origin main) and set the description, topics, protected v* tags and settings by hand, as in the handbook's checklist.")
}

# --- 7. GitHub repository and mirror --------------------------------------------------------------

if ($githubSetup) {
    Invoke-GitHub POST "/orgs/$org/repos" @{
        name = $path; description = $githubDescription; homepage = 'https://pigeonstudios.co.uk/free/'
        private = $false; auto_init = $false
    } | Out-Null
    Invoke-GitHub PUT "/repos/$org/$path/topics" @{ names = $githubTopics } | Out-Null
    Write-Host "  GitHub repository created: $githubUrl" -ForegroundColor Green

    foreach ($file in 'protect-main.json', 'protect-release-tags.json') {
        $ruleset = [System.IO.File]::ReadAllText((Join-Path $Handbook "github\rulesets\$file"), $utf8)
        $made = Invoke-GitHub POST "/repos/$org/$path/rulesets" $ruleset
        Write-Host "  Ruleset added: $($made.name)" -ForegroundColor Green
    }

    # The push mirror: SSH as git@github.com, checked against GitHub's published host keys, using a key
    # GitLab makes for this mirror alone. It never force-pushes (keep divergent refs) and mirrors every
    # branch and tag, so a v* tag on GitLab runs the GitHub release workflow.
    $hostKeys = @((Invoke-RestMethod -Uri 'https://api.github.com/meta' -Headers @{ 'User-Agent' = 'New-PigeonProject' }).ssh_keys | ForEach-Object { "github.com $_" })
    $mirror = Invoke-GitLab POST "/projects/$($project.id)/remote_mirrors" @{
        url = "ssh://git@github.com/$org/$path.git"; auth_method = 'ssh_public_key'; host_keys = $hostKeys
        enabled = $true; keep_divergent_refs = $true; only_protected_branches = $false
    }
    $mirrorKey = (Invoke-GitLab GET "/projects/$($project.id)/remote_mirrors/$($mirror.id)/public_key").public_key
    Invoke-GitHub POST "/repos/$org/$path/keys" @{ title = "GitLab push mirror ($groupPath/$path)"; key = $mirrorKey; read_only = $false } | Out-Null
    Write-Host '  Push mirror created, and its key added to GitHub as a deploy key with write access.' -ForegroundColor Green

    Invoke-GitLab POST "/projects/$($project.id)/remote_mirrors/$($mirror.id)/sync" | Out-Null
    $state = $null
    for ($i = 0; $i -lt 24; $i++) {
        Start-Sleep -Seconds 5
        $state = Invoke-GitLab GET "/projects/$($project.id)/remote_mirrors/$($mirror.id)"
        if ($state.update_status -in 'finished', 'failed') { break }
    }
    if ($state.update_status -eq 'finished') {
        Write-Host '  Mirror pushed main to GitHub.' -ForegroundColor Green
    } else {
        $todo.Add("Mirror: it reported '$($state.update_status)'$(if ($state.last_error) { ": $($state.last_error)" }). Check Settings -> Repository -> Mirroring repositories on GitLab and press Update now; if the host keys were refused, delete the mirror and add it again through the form (handbook: GitHub).")
    }
}

# --- What's left ----------------------------------------------------------------------------------

if (-not $Icon) {
    $todo.Add("Icon: add a glyph for '$path' to the handbook's brand/tools/make-icons.js, run it, and upload the PNG to the GitLab project (handbook: Brand and icons), or pass -Icon next time.")
}
$images = [regex]::Matches([System.IO.File]::ReadAllText((Join-Path $localFolder 'README.md'), $utf8), '<img src="(?!https?:)([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
if ($images) {
    $todo.Add("Images: the README shows $($images -join ' and '), which don't exist yet, so the links check fails until they're added. Banners are drawn as in the handbook's Brand and icons.")
}
if ($Kind -eq 'Free') {
    if (-not $githubSetup) {
        $todo.Add("GitHub: with both GITLAB_TOKEN and GITHUB_TOKEN set this is done for you. By hand: create $githubUrl (public, empty, description '$githubDescription', website https://pigeonstudios.co.uk/free/, topics $($githubTopics -join ', ')), import the two rulesets from the handbook's github/rulesets/, and add the deploy key and GitLab push mirror (handbook: GitHub).")
    }
    if ($Type -ne 'FiveM') {
        $todo.Add('GitHub workflows: copy .github/workflows/ci.yml and release.yml from an existing General free project (Monday to Discord), so tags build the release on GitHub.')
    }
    $todo.Add('Website: in WordPress admin -> GitHub, press Refresh now to list it on the Free releases page straight away (otherwise within the hour), then Set up webhooks on every repository to add its webhook.')
    $todo.Add("Lists of free resources: the GitHub, CI and studio layout tables in the handbook, and the profile table and Q&A and Ideas dropdowns in Repo Standards.")
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
