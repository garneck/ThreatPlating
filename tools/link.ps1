[CmdletBinding()]
param(
	[string] $AddOnsPath,
	[switch] $Remove
)

# Points Interface\AddOns\ThreatPlating at this checkout with a directory junction, so
# /reload picks up working-tree edits with no copy step.
#
# This is a development convenience and it is deliberately incompatible with the release
# tooling: while the link is in place, tools\install.ps1 refuses to replace it (see the
# reparse-point guard there), and therefore tools\push.ps1 cannot complete either. That
# is the point. A junction deploys the working tree, including uncommitted work, so the
# "a push only ever deploys the pushed commit" guarantee cannot hold at the same time.
#
# Run with -Remove before publishing.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Common.ps1")

$projectRoot = (Get-Item -LiteralPath (Split-Path -Parent $PSScriptRoot)).FullName
$addOnsDirectory = Resolve-AddOnsDirectory -AddOnsPath $AddOnsPath
$destination = Join-Path $addOnsDirectory.FullName "ThreatPlating"

if (Test-Path -LiteralPath $destination) {
	$existing = Get-Item -LiteralPath $destination -Force

	if (-not (Test-ReparsePoint -Item $existing)) {
		if ($Remove) {
			throw "$destination is a real directory, not a link. Remove it yourself if you are sure; this script only manages links."
		}
		throw "$destination already exists and is not a link. Move or delete the installed copy first."
	}

	$target = $existing.Target
	if ($target -is [array]) {
		$target = $target[0]
	}
	$resolvedTarget = $null
	if ($target) {
		$resolvedTarget = [System.IO.Path]::GetFullPath($target).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
	}
	$expectedTarget = $projectRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar)

	if ($Remove) {
		if ($resolvedTarget -and -not $resolvedTarget.Equals($expectedTarget, [StringComparison]::OrdinalIgnoreCase)) {
			throw "Refusing to remove a link that points at $resolvedTarget rather than this checkout."
		}
		# Directory.Delete removes the junction itself and never follows into the target.
		[System.IO.Directory]::Delete($destination)
		Write-Host "Removed the development link at $destination"
		return
	}

	if ($resolvedTarget -and $resolvedTarget.Equals($expectedTarget, [StringComparison]::OrdinalIgnoreCase)) {
		Write-Host "Already linked: $destination -> $projectRoot"
		return
	}

	throw "$destination is already linked to $resolvedTarget. Run with -Remove first."
}

if ($Remove) {
	Write-Host "Nothing to remove: $destination does not exist"
	return
}

# Junction rather than SymbolicLink: junctions work for directories without Developer
# Mode or an elevated shell, and the WoW client follows them identically.
New-Item -ItemType Junction -Path $destination -Value $projectRoot | Out-Null

$created = Get-Item -LiteralPath $destination -Force
if (-not (Test-ReparsePoint -Item $created)) {
	throw "Created $destination but it is not a link."
}

$tocContent = Get-Content -LiteralPath (Join-Path $projectRoot "ThreatPlating.toc") -Raw
foreach ($runtimeFile in @("ThreatPlating.toc") + @(Get-AddonRuntimeFile -TocContent $tocContent)) {
	if (-not (Test-Path -LiteralPath (Join-Path $destination $runtimeFile) -PathType Leaf)) {
		throw "The link is in place but $runtimeFile is not visible through it."
	}
}

Write-Host "Linked $destination -> $projectRoot"
Write-Host "The working tree is now what the client loads. Run tools\link.ps1 -Remove before publishing."
