<#
.SYNOPSIS
    Saves the GitLab or GitHub token for the Pigeon project commands in Windows Credential Manager.

.DESCRIPTION
    Asks for the token without showing it. It's kept in your Windows account, so New-PigeonProject.ps1,
    Publish-PigeonProject.ps1 and Release-PigeonProject.ps1 find it in every session. Run it again to replace a
    token. The handbook's Starting a new project page says what each token needs.

.PARAMETER Service
    GitLab or GitHub.

.PARAMETER Remove
    Deletes the saved token. Revoke it on GitLab or GitHub as well.

.EXAMPLE
    .\tools\Set-PigeonToken.ps1 -Service GitLab
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidateSet('GitLab', 'GitHub')] [string] $Service,
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'PigeonCommon.ps1')

if ($Remove) {
    if ([PigeonCredentials]::Delete("PigeonStudios/$Service")) { Write-Host "Removed the saved $Service token." -ForegroundColor Green }
    else { Write-Host "There was no saved $Service token." }
    return
}

$secure = Read-Host "$Service token" -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    if (-not $token) { throw 'No token entered.' }
    [PigeonCredentials]::Write("PigeonStudios/$Service", $token)
} finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer) }

# A new session picks up the saved token; check it now through the same requests the commands use.
. (Join-Path $PSScriptRoot 'PigeonCommon.ps1')
if ($Service -eq 'GitLab') { Assert-GitLabToken } else { Assert-GitHubToken }
Write-Host "Saved the $Service token." -ForegroundColor Green
