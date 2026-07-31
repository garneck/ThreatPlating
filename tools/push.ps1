[CmdletBinding()]
param(
	[string] $Remote = "origin"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$branch = (& git -C $projectRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($branch)) {
	throw "ThreatPlating must be on a branch before it can be pushed."
}
if ($branch -ne "main") {
	throw "ThreatPlating publishing must run from main, not $branch."
}

$worktreeStatus = @(& git -C $projectRoot status --porcelain --untracked-files=all)
if ($LASTEXITCODE -ne 0) {
	throw "Could not inspect the ThreatPlating working tree."
}
if ($worktreeStatus.Count -ne 0) {
	throw "Commit or remove all working-tree changes before publishing main."
}

& (Join-Path $PSScriptRoot "check.ps1")
if ($LASTEXITCODE -ne 0) {
	throw "Validation failed; main was not pushed or installed."
}

$revision = (& git -C $projectRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0) {
	throw "Could not resolve the current ThreatPlating revision."
}

& git -C $projectRoot push -u $Remote $branch
if ($LASTEXITCODE -ne 0) {
	throw "Push failed; the WoW addon was not replaced."
}

$remoteRevision = (& git -C $projectRoot rev-parse "$Remote/$branch").Trim()
if ($LASTEXITCODE -ne 0 -or $remoteRevision -ne $revision) {
	throw "The remote branch does not match $revision; the WoW addon was not replaced."
}

& (Join-Path $PSScriptRoot "install.ps1") -Revision $revision
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
