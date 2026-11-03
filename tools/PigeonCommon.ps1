# What New-PigeonProject.ps1, Publish-PigeonProject.ps1 and Release-PigeonProject.ps1 share: the tokens, the
# GitLab and GitHub requests, and the changes a release makes to a project's files. Dot-source it.

$org = 'pigeon-studios-uk'
$gitlabGroup = 'pigeon-studios'
$api = 'https://gitlab.com/api/v4'
$utf8 = New-Object System.Text.UTF8Encoding($false)

# --- Tokens ---------------------------------------------------------------------------------------

# Tokens are kept in Windows Credential Manager (Set-PigeonToken.ps1), so they last between sessions without
# being in a file. An environment variable overrides the saved one.
if (-not ('PigeonCredentials' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PigeonCredentials {
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct Credential {
        public int Flags; public int Type; public string TargetName; public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public int BlobSize; public IntPtr Blob; public int Persist; public int AttributeCount;
        public IntPtr Attributes; public string TargetAlias; public string UserName;
    }
    [DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool CredRead(string target, int type, int flags, out IntPtr credential);
    [DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool CredWrite(ref Credential credential, int flags);
    [DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool CredDelete(string target, int type, int flags);
    [DllImport("advapi32")] static extern void CredFree(IntPtr buffer);

    public static string Read(string target) {
        IntPtr pointer;
        if (!CredRead(target, 1, 0, out pointer)) return null;
        try {
            Credential credential = (Credential)Marshal.PtrToStructure(pointer, typeof(Credential));
            return Marshal.PtrToStringUni(credential.Blob, credential.BlobSize / 2);
        } finally { CredFree(pointer); }
    }
    public static void Write(string target, string secret) {
        byte[] bytes = System.Text.Encoding.Unicode.GetBytes(secret);
        Credential credential = new Credential();
        credential.Type = 1; credential.TargetName = target; credential.UserName = "token"; credential.Persist = 2;
        credential.BlobSize = bytes.Length;
        credential.Blob = Marshal.AllocHGlobal(bytes.Length);
        try {
            Marshal.Copy(bytes, 0, credential.Blob, bytes.Length);
            if (!CredWrite(ref credential, 0)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
        } finally { Marshal.FreeHGlobal(credential.Blob); }
    }
    public static bool Delete(string target) { return CredDelete(target, 1, 0); }
}
'@
}

function Get-PigeonToken([ValidateSet('GitLab', 'GitHub')] [string] $service) {
    $fromEnvironment = if ($service -eq 'GitLab') { $env:GITLAB_TOKEN } else { $env:GITHUB_TOKEN }
    if ($fromEnvironment) { return $fromEnvironment }
    [PigeonCredentials]::Read("PigeonStudios/$service")
}

$gitlabToken = Get-PigeonToken GitLab
$githubToken = Get-PigeonToken GitHub
$headers = @{ 'PRIVATE-TOKEN' = $gitlabToken }
$ghHeaders = @{
    Authorization = "Bearer $githubToken"; Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'Pigeon-Studios-Tools'
}

# --- Requests -------------------------------------------------------------------------------------

# Bodies go as UTF-8 bytes: Windows PowerShell would otherwise send them in the ANSI code page. The comma
# returns the bytes as one array; without it PowerShell unrolls them into a list of numbers, which
# Invoke-RestMethod sends as text ("123 34 ...") and the API rejects as invalid JSON.
function ConvertTo-Body($body) {
    if ($null -eq $body) { return $null }
    $json = if ($body -is [string]) { $body } else { $body | ConvertTo-Json -Depth 10 }
    , [System.Text.Encoding]::UTF8.GetBytes($json)
}

function Invoke-GitLab([string] $method, [string] $uri, $body) {
    Invoke-RestMethod -Method $method -Uri "$api$uri" -Headers $headers -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-Body $body)
}

function Invoke-GitHub([string] $method, [string] $uri, $body) {
    Invoke-RestMethod -Method $method -Uri "https://api.github.com$uri" -Headers $ghHeaders -ContentType 'application/json; charset=utf-8' -Body (ConvertTo-Body $body)
}

# PowerShell carries on when a native command fails, so every git call checks its own exit code. A warning
# on stderr isn't a failure, but with Stop it would end the script when the output is being captured.
function Invoke-Git {
    $ErrorActionPreference = 'Continue'
    & git @args
    if ($LASTEXITCODE -ne 0) { throw "git $args failed with exit code $LASTEXITCODE." }
}

# The same, for a git command that's allowed to fail: true if it worked. Its output is left out.
function Test-Git {
    $ErrorActionPreference = 'Continue'
    & git @args 2>&1 | Out-Null
    $LASTEXITCODE -eq 0
}

# A read-only request that reports a 4xx instead of stopping: its status, headers and body as UTF-8 text.
function Get-Url([string] $uri, [hashtable] $requestHeaders) {
    try {
        $response = Invoke-WebRequest -Uri $uri -Headers $requestHeaders -UseBasicParsing
        [pscustomobject]@{ Status = [int] $response.StatusCode; Headers = $response.Headers; Content = $utf8.GetString($response.RawContentStream.ToArray()) }
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

function Assert-GitLabToken {
    if (-not $gitlabToken) { throw 'No GitLab token. Save one with .\tools\Set-PigeonToken.ps1 -Service GitLab.' }
    $self = Get-Url "$api/personal_access_tokens/self" $headers
    if ($self.Status -ne 200) { throw "GitLab refused the token (HTTP $($self.Status)). It may have expired or been revoked; make a new one (handbook: Starting a new project)." }
    $info = $self.Content | ConvertFrom-Json
    if ($info.scopes -notcontains 'api') { throw "The GitLab token has the scopes '$($info.scopes -join ', ')'. It needs api." }
    Show-TokenExpiry 'GitLab token' $info.expires_at
}

function Assert-GitHubToken {
    if (-not $githubToken) { throw 'No GitHub token. Save one with .\tools\Set-PigeonToken.ps1 -Service GitHub.' }
    # Deploy keys need Administration, which an unapproved or wrongly scoped token doesn't have.
    $keys = Get-Url "https://api.github.com/repos/$org/.github/keys" $ghHeaders
    if ($keys.Status -eq 401) { throw 'GitHub refused the token. It may have expired or been revoked; make a new one (handbook: Starting a new project).' }
    if ($keys.Status -ne 200) { throw "The GitHub token can't administer $org (HTTP $($keys.Status)). It needs resource owner $org, all repositories and Administration read and write, and the organisation must have approved it." }
    Show-TokenExpiry 'GitHub token' $keys.Headers['github-authentication-token-expiration']
}

# --- Projects on GitLab ---------------------------------------------------------------------------

# Finds a project from its path or slug ("pigeon-notes", "notes", "pg-shrike", "shrike") wherever it lives.
function Find-PigeonProject([string] $slug) {
    $names = @($slug, "pigeon-$slug", "pg-$slug") | Select-Object -Unique
    foreach ($area in 'fivem/releases/github', 'fivem/dev-releases', 'tools', 'bots', 'web') {
        foreach ($name in $names) {
            $found = Get-Url "$api/projects/$([uri]::EscapeDataString("$gitlabGroup/$area/$name"))" $headers
            if ($found.Status -eq 200) { return $found.Content | ConvertFrom-Json }
        }
    }
    throw "There's no project called $slug on GitLab. Create it with New-PigeonProject.ps1."
}

function Get-ProjectFile($project, [string] $file) {
    $response = Get-Url "$api/projects/$($project.id)/repository/files/$([uri]::EscapeDataString($file))/raw?ref=$($project.default_branch)" $headers
    if ($response.Status -eq 200) { $response.Content } else { $null }
}

function Get-ProjectTree($project) {
    $all = @()
    for ($page = 1; ; $page++) {
        $batch = @(Invoke-GitLab GET "/projects/$($project.id)/repository/tree?recursive=true&per_page=100&page=$page&ref=$($project.default_branch)")
        $all += $batch
        if ($batch.Count -lt 100) { break }
    }
    @($all | Where-Object { $_.type -eq 'blob' } | ForEach-Object { $_.path })
}

# --- What a release changes -----------------------------------------------------------------------

# The next version from the current one and -Bump.
function Get-NextVersion([string] $current, [ValidateSet('patch', 'minor', 'major')] [string] $bump) {
    $core = ($current -split '-')[0]
    $parts = @($core -split '\.' | ForEach-Object { [int] $_ })
    switch ($bump) {
        'major' { "$($parts[0] + 1).0.0" }
        'minor' { "$($parts[0]).$($parts[1] + 1).0" }
        'patch' { "$($parts[0]).$($parts[1]).$($parts[2] + 1)" }
    }
}

# Moves what's under Unreleased into a dated section for the version and leaves a fresh Unreleased above it.
# Empty headings are dropped. An Unreleased section with nothing in it is an error: there's nothing to release.
function Update-Changelog([string] $text, [string] $version, [string] $date, [string] $repoUrl, [bool] $github) {
    $text = $text.Replace("`r`n", "`n")
    $match = [regex]::Match($text, '(?ms)^## \[Unreleased\][^\n]*\n(.*?)(?=^## \[|^<!--|^\[[^\]]+\]: |\z)')
    if (-not $match.Success) { throw 'CHANGELOG.md has no ## [Unreleased] section.' }

    $kept = New-Object System.Collections.Generic.List[string]
    $blocks = [regex]::Split($match.Groups[1].Value.Trim(), '(?m)^(?=### )')
    foreach ($block in $blocks) {
        $body = ($block -replace '(?m)^### .*$', '').Trim()
        if ($body) { $kept.Add($block.Trim()) }
    }
    if ($kept.Count -eq 0) { throw 'Nothing is listed under ## [Unreleased] in CHANGELOG.md, so there is nothing to release.' }

    $section = "## [Unreleased]`n`n## [$version] - $date`n`n$($kept -join "`n`n")`n`n"
    $text = $text.Remove($match.Index, $match.Length).Insert($match.Index, $section)

    if ($repoUrl) {
        $compare = if ($github) { "$repoUrl/compare/v$version...HEAD" } else { "$repoUrl/-/compare/v$version...HEAD" }
        $tagLink = if ($github) { "$repoUrl/releases/tag/v$version" } else { "$repoUrl/-/tags/v$version" }
        $replacement = "[Unreleased]: $compare`n[$version]: $tagLink"
        if ($text -match '(?m)^\[Unreleased\]: .*$') { $text = [regex]::Replace($text, '(?m)^\[Unreleased\]: .*$', { param($m) $replacement }) }
        else { $text = $text.TrimEnd() + "`n`n$replacement`n" }
    }
    $text
}

# The version line of a manifest or package.json, changed. Other content is left exactly as it is.
function Set-ManifestVersion([string] $text, [string] $version) {
    [regex]::new("(?m)^(\s*version\s+['""])[^'""]+(['""])").Replace($text, { param($m) "$($m.Groups[1].Value)$version$($m.Groups[2].Value)" }, 1)
}

function Set-PackageVersion([string] $text, [string] $version) {
    [regex]::new('("version"\s*:\s*")[^"]+(")').Replace($text, { param($m) "$($m.Groups[1].Value)$version$($m.Groups[2].Value)" }, 1)
}
