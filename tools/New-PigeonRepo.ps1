<#
.SYNOPSIS
    Copies the Pigeon Studios standard files into a repository.

.DESCRIPTION
    Copies the licence, README, CHANGELOG, NOTICE, editor and Git settings, CODEOWNERS and, where needed,
    the private CONTRIBUTING and pull request template into the target folder, then fills in the placeholders
    you pass. Existing files are never overwritten unless you use -Force.

    Free repositories on GitHub don't get CONTRIBUTING, SECURITY, SUPPORT, CODE_OF_CONDUCT, issue forms or a
    PR template, because GitHub supplies those from the pigeon-studios-uk/.github repository (the organisation defaults). On GitLab there are no
    shared defaults on the Free plan, so -Platform GitLab copies those policies and the .gitlab templates too.

.PARAMETER Path
    The repository folder to set up.

.PARAMETER Kind
    Free, Paid or Internal.

.PARAMETER Platform
    GitHub (default) or GitLab.

.PARAMETER Type
    For free repositories: FiveM (default) for a FiveM or RedM resource, or General for anything else
    (Discord bots, tools, libraries, website components). Paid repositories are always FiveM; internal ones use
    the internal README.

.PARAMETER Name
    Display name, for {{RESOURCE_NAME}}, {{PRODUCT_NAME}} and {{PROJECT_NAME}}.

.PARAMETER Folder
    Resource folder / repository name, for {{RESOURCE_FOLDER}} and {{REPO}}. Defaults to the target folder's name.

.PARAMETER Description
    One-sentence description, for {{SHORT_DESCRIPTION}}.

.PARAMETER Year
    Copyright year or range, for {{YEAR}}. Defaults to the current year.

.PARAMETER Force
    Overwrite files that already exist.

.EXAMPLE
    .\tools\New-PigeonRepo.ps1 -Path D:\PigeonStudios\Repos\fivem\releases\github\pigeon-dice -Kind Free -Name "Pigeon Dice" -Description "Roleplay dice rolling with cooldowns and chat output."

.EXAMPLE
    .\tools\New-PigeonRepo.ps1 -Path D:\PigeonStudios\Repos\tools\flightpath-systems -Kind Internal -Platform GitLab -Name "FlightPath Systems"

.EXAMPLE
    .\tools\New-PigeonRepo.ps1 -Path D:\PigeonStudios\Repos\tools\monday-discord-relay -Kind Free -Type General -Name "Monday Discord Relay"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $Path,
    [Parameter(Mandatory)] [ValidateSet('Free', 'Paid', 'Internal')] [string] $Kind,
    [ValidateSet('GitHub', 'GitLab')] [string] $Platform = 'GitHub',
    [ValidateSet('FiveM', 'General')] [string] $Type = 'FiveM',
    [Parameter(Mandatory)] [string] $Name,
    [string] $Folder,
    [string] $Description = '',
    [string] $Year = (Get-Date).Year.ToString(),
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
}
$Path = (Resolve-Path -LiteralPath $Path).Path
if (-not $Folder) { $Folder = Split-Path -Leaf $Path }

# Source (relative to this repository) -> destination (relative to the target repository).
$copies = [ordered]@{}
$copies["licences/$($Kind.ToLower())/LICENSE.md"] = 'LICENSE.md'
$readme = if ($Kind -eq 'Free' -and $Type -eq 'General') { 'templates/free/README.general.md' } else { "templates/$($Kind.ToLower())/README.md" }
$copies[$readme] = 'README.md'
foreach ($file in 'CHANGELOG.md', '.editorconfig', '.gitattributes', '.gitignore', '.github/CODEOWNERS') {
    $copies["templates/common/$file"] = $file
}
if ($Kind -ne 'Internal') {
    $copies['templates/common/NOTICE.md'] = 'NOTICE.md'
}
if ($Kind -eq 'Paid') {
    $copies['templates/paid/docs/INTERNAL.md'] = 'docs/INTERNAL.md'
}
if ($Kind -eq 'Internal' -or ($Kind -eq 'Free' -and $Type -eq 'General')) {
    $copies['templates/common/.env.example'] = '.env.example'
}
if ($Kind -ne 'Free') {
    $copies["templates/$($Kind.ToLower())/CONTRIBUTING.md"] = 'CONTRIBUTING.md'
    if ($Platform -eq 'GitHub') {
        $copies["templates/$($Kind.ToLower())/.github/pull_request_template.md"] = '.github/pull_request_template.md'
    }
}
if ($Platform -eq 'GitLab') {
    $policies = if ($Kind -eq 'Free') { 'CONTRIBUTING.md', 'SECURITY.md', 'SUPPORT.md', 'CODE_OF_CONDUCT.md' } else { 'SECURITY.md', 'CODE_OF_CONDUCT.md' }
    foreach ($file in $policies) { $copies[$file] = $file }
    $gitlabSet = if ($Kind -eq 'Free') { 'free' } else { 'private' }
    Get-ChildItem -LiteralPath (Join-Path $root "templates/gitlab/$gitlabSet/.gitlab") -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring((Join-Path $root "templates/gitlab/$gitlabSet").Length + 1) -replace '\\', '/'
        $copies["templates/gitlab/$gitlabSet/$relative"] = $relative
    }
    # Code owners need GitLab Premium; the file does nothing on the Free plan.
    $copies.Remove('templates/common/.github/CODEOWNERS')
}

$placeholders = @{
    '{{RESOURCE_NAME}}'     = $Name
    '{{PRODUCT_NAME}}'      = $Name
    '{{PROJECT_NAME}}'      = $Name
    '{{RESOURCE_FOLDER}}'   = $Folder
    '{{PROJECT_FOLDER}}'    = $Folder
    '{{REPO}}'              = $Folder
    '{{SLUG}}'              = $Folder
    '{{SHORT_DESCRIPTION}}' = $Description
    '{{YEAR}}'              = $Year
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
$copied = 0
$skipped = 0

foreach ($entry in $copies.GetEnumerator()) {
    $source = Join-Path $root $entry.Key
    $target = Join-Path $Path $entry.Value

    if ((Test-Path -LiteralPath $target) -and -not $Force) {
        Write-Host "  skip   $($entry.Value) (already exists; use -Force to overwrite)" -ForegroundColor DarkGray
        $skipped++
        continue
    }
    if (-not $PSCmdlet.ShouldProcess($target, "Copy $($entry.Key)")) { continue }

    $directory = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $text = [System.IO.File]::ReadAllText($source, $utf8)
    foreach ($key in $placeholders.Keys) {
        if ($placeholders[$key]) { $text = $text.Replace($key, $placeholders[$key]) }
    }
    [System.IO.File]::WriteAllText($target, $text, $utf8)
    Write-Host "  copy   $($entry.Value)" -ForegroundColor Green
    $copied++
}

Write-Host ''
Write-Host "$copied copied, $skipped skipped. $Kind repository on $Platform." -ForegroundColor Cyan

$remaining = Get-ChildItem -LiteralPath $Path -Recurse -File -Include *.md, *.yml, *.example |
    Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' } |
    Select-String -Pattern '\{\{[A-Z_]+\}\}' -AllMatches |
    ForEach-Object { $_.Matches.Value } | Sort-Object -Unique

if ($remaining) {
    Write-Host "Still to fill in: $($remaining -join ', ')" -ForegroundColor Yellow
}

if ($Kind -eq 'Free' -and $Platform -eq 'GitHub') {
    Write-Host 'Remember: delete any old CONTRIBUTING, SECURITY, SUPPORT or CODE_OF_CONDUCT files and .github issue/PR templates so the account defaults show.' -ForegroundColor Yellow
}
Write-Host 'Delete any old LICENSE file without an extension; keep only LICENSE.md.' -ForegroundColor Yellow
