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
