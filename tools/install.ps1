[CmdletBinding()]
param(
	[string] $AddOnsPath,
	[string] $Revision
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$runtimeFiles = @(
	"ThreatPlating.toc",
	"Init.lua",
	"Threat.lua",
	"Display.lua",
	"Nameplates.lua",
	"Config.lua"
)

if ([string]::IsNullOrWhiteSpace($AddOnsPath)) {
	$AddOnsPath = $env:THREATPLATING_ADDONS_PATH
}

if ([string]::IsNullOrWhiteSpace($AddOnsPath)) {
	$detectedPaths = @(
		@(Get-PSDrive -PSProvider FileSystem | ForEach-Object {
			$candidate = Join-Path $_.Root "World of Warcraft\_anniversary_\Interface\AddOns"
			if (Test-Path -LiteralPath $candidate -PathType Container) {
				(Get-Item -LiteralPath $candidate).FullName
			}
		}) | Sort-Object -Unique
	)

	if ($detectedPaths.Count -ne 1) {
		throw "Could not identify one TBC Anniversary AddOns folder. Pass -AddOnsPath or set THREATPLATING_ADDONS_PATH."
	}

	$AddOnsPath = $detectedPaths[0]
}

$addOnsDirectory = Get-Item -LiteralPath $AddOnsPath
if (-not $addOnsDirectory.PSIsContainer -or $addOnsDirectory.Name -ne "AddOns") {
	throw "The install path must be an existing AddOns directory: $AddOnsPath"
}

$interfaceDirectory = $addOnsDirectory.Parent
$clientDirectory = $interfaceDirectory.Parent
if ($interfaceDirectory.Name -ne "Interface" -or $clientDirectory.Name -ne "_anniversary_") {
	throw "Refusing to install outside a TBC Anniversary Interface\AddOns directory: $($addOnsDirectory.FullName)"
}

$destination = Join-Path $addOnsDirectory.FullName "ThreatPlating"
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
		$resolvedRevision = & git -C $projectRoot rev-parse --verify --end-of-options "${Revision}^{commit}"
		if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolvedRevision)) {
			throw "Could not resolve revision $Revision to a commit."
		}
		$resolvedRevision = $resolvedRevision.Trim()

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
		if (($existingDestination.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
			throw "Refusing to replace a linked addon directory: $destination"
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
				($failedDestination.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
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
			($backupDirectory.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
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
