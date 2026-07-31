[CmdletBinding()]
param(
	[string] $AddOnsPath,
	[string] $Revision
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Common.ps1")

$projectRoot = Split-Path -Parent $PSScriptRoot

$resolvedRevision = $null
if ([string]::IsNullOrWhiteSpace($Revision)) {
	$tocContent = Get-Content -LiteralPath (Join-Path $projectRoot "ThreatPlating.toc") -Raw
}
else {
	$resolvedRevision = & git -C $projectRoot rev-parse --verify --end-of-options "${Revision}^{commit}"
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolvedRevision)) {
		throw "Could not resolve revision $Revision to a commit."
	}
	$resolvedRevision = $resolvedRevision.Trim()

	# Read the manifest from the revision being installed, not the working tree, so the
	# deployed file set always matches the deployed code.
	$tocContent = (& git -C $projectRoot show "${resolvedRevision}:ThreatPlating.toc") -join "`n"
	if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tocContent)) {
		throw "Could not read ThreatPlating.toc from revision $Revision."
	}
}

$runtimeFiles = @("ThreatPlating.toc") + @(Get-AddonRuntimeFile -TocContent $tocContent)

$addOnsDirectory = Resolve-AddOnsDirectory -AddOnsPath $AddOnsPath

$destination = Join-Path $addOnsDirectory.FullName "ThreatPlating"

# Installing over the checkout would move it aside and then delete it, taking .git with it.
$resolvedRoot = (Get-Item -LiteralPath $projectRoot).FullName
$resolvedDestination = [System.IO.Path]::GetFullPath($destination)
$destinationPrefix = $resolvedDestination.TrimEnd([System.IO.Path]::DirectorySeparatorChar) +
	[System.IO.Path]::DirectorySeparatorChar
if (
	$resolvedRoot.Equals($resolvedDestination, [StringComparison]::OrdinalIgnoreCase) -or
	$resolvedRoot.StartsWith($destinationPrefix, [StringComparison]::OrdinalIgnoreCase)
) {
	throw "Refusing to install over the checkout itself: $resolvedDestination"
}

$staging = Join-Path $addOnsDirectory.FullName (".ThreatPlating.deploy." + [Guid]::NewGuid().ToString("N"))
$archive = $null
$backup = $null

New-Item -ItemType Directory -Path $staging | Out-Null

try {
	if ([string]::IsNullOrWhiteSpace($Revision)) {
		foreach ($runtimeFile in $runtimeFiles) {
			$source = Join-Path $projectRoot $runtimeFile
			if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
				throw "Missing runtime file: $source"
			}

			Copy-Item -LiteralPath $source -Destination $staging
		}
	}
	else {
		$archive = Join-Path ([System.IO.Path]::GetTempPath()) ("ThreatPlating." + [Guid]::NewGuid().ToString("N") + ".zip")
		& git -C $projectRoot archive --format=zip "--output=$archive" $resolvedRevision -- @runtimeFiles
		if ($LASTEXITCODE -ne 0) {
			throw "Could not export revision $Revision."
		}

		Expand-Archive -LiteralPath $archive -DestinationPath $staging
	}

	foreach ($runtimeFile in $runtimeFiles) {
		$stagedFile = Join-Path $staging $runtimeFile
		if (-not (Test-Path -LiteralPath $stagedFile -PathType Leaf)) {
			throw "Staged addon is missing $runtimeFile."
		}
	}

	if (Test-Path -LiteralPath $destination) {
		$existingDestination = Get-Item -LiteralPath $destination -Force
		if (-not $existingDestination.PSIsContainer) {
			throw "The addon destination exists but is not a directory: $destination"
		}
		if (Test-ReparsePoint -Item $existingDestination) {
			throw "Refusing to replace a linked addon directory: $destination. Run tools\link.ps1 -Remove first if you no longer want the development symlink."
		}
		if ($existingDestination.Parent.FullName -ne $addOnsDirectory.FullName) {
			throw "Refusing unexpected addon destination: $destination"
		}

		$backup = Join-Path $addOnsDirectory.FullName (".ThreatPlating.backup." + [Guid]::NewGuid().ToString("N"))
		Move-Item -LiteralPath $existingDestination.FullName -Destination $backup
	}

	try {
		Move-Item -LiteralPath $staging -Destination $destination

		foreach ($runtimeFile in $runtimeFiles) {
			$installedFile = Join-Path $destination $runtimeFile
			if (-not (Test-Path -LiteralPath $installedFile -PathType Leaf)) {
				throw "Installed addon is missing $runtimeFile."
			}
		}
	}
	catch {
		if (Test-Path -LiteralPath $destination) {
			$failedDestination = Get-Item -LiteralPath $destination -Force
			if (
				-not $failedDestination.PSIsContainer -or
				$failedDestination.Parent.FullName -ne $addOnsDirectory.FullName -or
				(Test-ReparsePoint -Item $failedDestination)
			) {
				throw "Installation failed and the partial destination could not be removed safely: $destination"
			}
			Remove-Item -LiteralPath $failedDestination.FullName -Recurse -Force
		}

		if ($backup -and (Test-Path -LiteralPath $backup -PathType Container)) {
			Move-Item -LiteralPath $backup -Destination $destination
			$backup = $null
		}
		throw
	}

	if ($backup -and (Test-Path -LiteralPath $backup -PathType Container)) {
		$backupDirectory = Get-Item -LiteralPath $backup -Force
		if (
			$backupDirectory.Parent.FullName -ne $addOnsDirectory.FullName -or
			(Test-ReparsePoint -Item $backupDirectory)
		) {
			throw "Refusing to remove unexpected deployment backup: $backup"
		}
		Remove-Item -LiteralPath $backupDirectory.FullName -Recurse -Force
		$backup = $null
	}
}
finally {
	if ($archive -and (Test-Path -LiteralPath $archive)) {
		Remove-Item -LiteralPath $archive -Force
	}
	if (Test-Path -LiteralPath $staging) {
		Remove-Item -LiteralPath $staging -Recurse -Force
	}
}

$sourceDescription = "the working tree"
if (-not [string]::IsNullOrWhiteSpace($Revision)) {
	$sourceDescription = "revision $Revision"
}

Write-Host "Installed ThreatPlating from $sourceDescription to $destination"
