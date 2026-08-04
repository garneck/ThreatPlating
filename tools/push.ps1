[CmdletBinding()]
param(
	[string] $Remote = "origin",
	[string] $Tag
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

$pushArguments = @("push", "--atomic", "-u", $Remote, $branch)
if (-not [string]::IsNullOrWhiteSpace($Tag)) {
	$tocContent = Get-Content -LiteralPath (Join-Path $projectRoot "ThreatPlating.toc") -Raw
	$versionMatch = [regex]::Match($tocContent, '(?m)^## Version: ([^\r\n]+)\r?$')
	if (-not $versionMatch.Success) {
		throw "Could not read the release version from ThreatPlating.toc."
	}

	$expectedTag = "v$($versionMatch.Groups[1].Value)"
	if ($Tag -ne $expectedTag) {
		throw "Release tag $Tag does not match ThreatPlating.toc version $($versionMatch.Groups[1].Value); expected $expectedTag."
	}

	$existingTagOutput = @(& git -C $projectRoot tag --list $Tag)
	if ($LASTEXITCODE -ne 0) {
		throw "Could not inspect local tag $Tag."
	}
	$existingTag = ($existingTagOutput -join "`n").Trim()
	if ([string]::IsNullOrWhiteSpace($existingTag)) {
		& git -C $projectRoot tag $Tag $revision
		if ($LASTEXITCODE -ne 0) {
			throw "Could not create release tag $Tag."
		}
	}

	$tagRevision = (& git -C $projectRoot rev-parse "${Tag}^{commit}").Trim()
	if ($LASTEXITCODE -ne 0 -or $tagRevision -ne $revision) {
		throw "Release tag $Tag must point at the current commit $revision."
	}

	$pushArguments += "refs/tags/${Tag}:refs/tags/${Tag}"
}

& git -C $projectRoot @pushArguments
if ($LASTEXITCODE -ne 0) {
	throw "Push failed; the WoW addon was not replaced."
}

$remoteRevision = (& git -C $projectRoot rev-parse "$Remote/$branch").Trim()
if ($LASTEXITCODE -ne 0 -or $remoteRevision -ne $revision) {
	throw "The remote branch does not match $revision; the WoW addon was not replaced."
}

if (-not [string]::IsNullOrWhiteSpace($Tag)) {
	$remoteTag = (& git -C $projectRoot ls-remote --tags $Remote "refs/tags/$Tag").Trim()
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteTag)) {
		throw "The remote release tag $Tag was not created; the WoW addon was not replaced."
	}

	$remoteTagRevision = ($remoteTag -split '\s+')[0]
	if ($remoteTagRevision -ne $revision) {
		throw "Remote release tag $Tag does not point at $revision; the WoW addon was not replaced."
	}
}

& (Join-Path $PSScriptRoot "install.ps1") -Revision $revision
if ($LASTEXITCODE -ne 0) {
	exit $LASTEXITCODE
}
