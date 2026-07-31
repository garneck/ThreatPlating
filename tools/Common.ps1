# Shared helpers for the Threat Plating tooling.
#
# Dot-source from a script in this directory:
#   . (Join-Path $PSScriptRoot "Common.ps1")

Set-StrictMode -Version Latest

# The TOC is the only manifest the client actually reads, so it is the single source of
# truth for which Lua files ship and in what order. Every other tool derives its list
# from here rather than keeping a copy.
function Get-AddonRuntimeFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string] $TocContent
	)

	$files = @(
		$TocContent -split "\r?\n" |
			ForEach-Object { $_.Trim() } |
			Where-Object { $_ -and $_ -notmatch '^#' -and $_ -match '\.lua$' }
	)

	if ($files.Count -eq 0) {
		throw "ThreatPlating.toc declares no Lua files."
	}

	$seen = @{}
	foreach ($file in $files) {
		if ($seen.ContainsKey($file)) {
			throw "ThreatPlating.toc lists $file more than once."
		}
		$seen[$file] = $true
	}

	return $files
}

# Resolves and validates the TBC Anniversary AddOns directory. Throws rather than
# guessing when the layout is not what the installer expects, because every caller is
# about to write into it.
function Resolve-AddOnsDirectory {
	[CmdletBinding()]
	param(
		[AllowEmptyString()]
		[AllowNull()]
		[string] $AddOnsPath
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
		throw "Refusing to operate outside a TBC Anniversary Interface\AddOns directory: $($addOnsDirectory.FullName)"
	}

	return $addOnsDirectory
}

function Test-ReparsePoint {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[System.IO.FileSystemInfo] $Item
	)

	return ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
}
