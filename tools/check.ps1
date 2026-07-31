$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Common.ps1")

$projectRoot = Split-Path -Parent $PSScriptRoot

# Ordered deliberately: pure math, then the database, then the mocked runtime, then the
# raid suite. Coverage of tests/test_*.lua is asserted below so a new suite cannot be
# silently skipped.
$testSuites = @(
	"tests/test_threat.lua",
	"tests/test_database.lua",
	"tests/test_runtime.lua",
	"tests/test_raid.lua"
)

function Get-MetadataVersion($path, $pattern, $label) {
	$content = Get-Content -LiteralPath $path -Raw
	$match = [regex]::Match($content, $pattern)
	if (-not $match.Success) {
		throw "Could not read $label version from $path."
	}

	return $match.Groups[1].Value
}

function Assert-CommandAvailable($command) {
	if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
		throw "Required validation command is unavailable: $command"
	}
}

Push-Location $projectRoot
try {
	Assert-CommandAvailable "lua"
	Assert-CommandAvailable "luac"
	Assert-CommandAvailable "luacheck"

	# std = "lua51" in .luacheckrc constrains globals, not syntax. Only a 5.1 luac rejects
	# `goto` and `//`, which the WoW VM cannot run.
	$luaBanner = (& lua -v 2>&1) -join " "
	if ($luaBanner -notmatch "Lua 5\.1") {
		throw "Lua 5.1 is required for WoW compatibility; found: $luaBanner"
	}
	$luacBanner = (& luac -v 2>&1) -join " "
	if ($luacBanner -notmatch "Lua 5\.1") {
		throw "luac from Lua 5.1 is required for WoW compatibility; found: $luacBanner"
	}

	$runtimeVersion = Get-MetadataVersion "Init.lua" 'addon\.version = "([^"]+)"' "runtime"
	$tocVersion = Get-MetadataVersion "ThreatPlating.toc" '(?m)^## Version: ([^\r\n]+)\r?$' "TOC"
	if ($runtimeVersion -ne $tocVersion) {
		throw "Version mismatch: Init.lua is $runtimeVersion but ThreatPlating.toc is $tocVersion."
	}

	$escapedVersion = [regex]::Escape($runtimeVersion)
	if ((Get-Content -LiteralPath "README.md" -Raw) -notmatch "working ``$escapedVersion`` addon") {
		throw "README.md does not identify release $runtimeVersion."
	}
	if ((Get-Content -LiteralPath "CHANGELOG.md" -Raw) -notmatch "(?m)^## $escapedVersion - ") {
		throw "CHANGELOG.md does not contain a $runtimeVersion release heading."
	}

	Write-Host "Release metadata: $runtimeVersion"

	$readme = Get-Content -LiteralPath "README.md" -Raw
	$verifiedBuild = Get-MetadataVersion "AGENTS.md" '- Verified build: `([^`]+)`' "verified build"
	$verifiedInterface = Get-MetadataVersion "AGENTS.md" '- TOC interface: `([^`]+)`' "verified interface"
	$verifiedSourceCommit = Get-MetadataVersion "AGENTS.md" '- Verified UI source commit: `([0-9a-f]+)`' "UI source"
	$tocInterface = Get-MetadataVersion "ThreatPlating.toc" '(?m)^## Interface: ([^\r\n]+)\r?$' "TOC interface"
	if ($tocInterface -ne $verifiedInterface) {
		throw "Interface mismatch: AGENTS.md verifies $verifiedInterface but ThreatPlating.toc uses $tocInterface."
	}

	$escapedBuild = [regex]::Escape($verifiedBuild)
	$escapedInterface = [regex]::Escape($verifiedInterface)
	if ($readme -notmatch "targeting TBC Anniversary client\s+``$escapedBuild`` \(``## Interface: $escapedInterface``\)") {
		throw "README.md does not identify verified client $verifiedBuild with interface $verifiedInterface."
	}

	$sourceLinks = [regex]::Matches(
		$readme,
		'https://github\.com/Gethe/wow-ui-source/blob/([0-9a-f]{40})/'
	)
	if ($sourceLinks.Count -lt 3) {
		throw "README.md must retain at least three pinned UI-source references."
	}
	foreach ($sourceLink in $sourceLinks) {
		if ($sourceLink.Groups[1].Value -ne $verifiedSourceCommit) {
			throw "README.md contains a UI-source link that is not pinned to $verifiedSourceCommit."
		}
	}

	Write-Host "Client metadata: build $verifiedBuild, interface $verifiedInterface, UI source $verifiedSourceCommit"

	# The TOC is the manifest the client reads, so it decides what gets compiled, tested,
	# and linted here. Nothing else keeps a copy of the list.
	$toc = Get-Content -LiteralPath "ThreatPlating.toc" -Raw
	$addonFiles = Get-AddonRuntimeFile -TocContent $toc

	foreach ($addonFile in $addonFiles) {
		if (-not (Test-Path -LiteralPath $addonFile -PathType Leaf)) {
			throw "ThreatPlating.toc declares $addonFile but the file does not exist."
		}
	}

	# A runtime file missing from the TOC never loads in game, and nothing else here
	# would notice, so assert the manifest is complete rather than merely consistent.
	$declared = @{}
	foreach ($addonFile in $addonFiles) {
		$declared[$addonFile] = $true
	}
	foreach ($onDisk in @(Get-ChildItem -LiteralPath $projectRoot -Filter *.lua -File)) {
		if (-not $declared.ContainsKey($onDisk.Name)) {
			throw "$($onDisk.Name) is not declared in ThreatPlating.toc and would never load in game."
		}
	}

	if ($toc -notmatch '(?m)^## SavedVariables: ThreatPlatingDB\r?$') {
		throw "ThreatPlating.toc must declare ## SavedVariables: ThreatPlatingDB."
	}
	if ($toc -notmatch '(?m)^## AddonCompartmentFunc: ThreatPlating_OnAddonCompartmentClick\r?$') {
		throw "ThreatPlating.toc must declare the AddOn Compartment entry point."
	}

	Write-Host "TOC manifest: $($addonFiles -join ', ')"

	# Same reasoning for the suites: the run order below is deliberate, but a suite that
	# exists on disk and is not run is worse than a reordered one.
	$scheduled = @{}
	foreach ($testSuite in $testSuites) {
		if (-not (Test-Path -LiteralPath $testSuite -PathType Leaf)) {
			throw "check.ps1 schedules $testSuite but the file does not exist."
		}
		$scheduled[(Split-Path -Leaf $testSuite)] = $true
	}
	foreach ($suiteOnDisk in @(Get-ChildItem -LiteralPath (Join-Path $projectRoot "tests") -Filter "test_*.lua" -File)) {
		if (-not $scheduled.ContainsKey($suiteOnDisk.Name)) {
			throw "tests/$($suiteOnDisk.Name) exists but check.ps1 never runs it."
		}
	}

	foreach ($addonFile in $addonFiles) {
		& luac -p $addonFile
		if ($LASTEXITCODE -ne 0) {
			exit $LASTEXITCODE
		}
	}

	foreach ($testSuite in $testSuites) {
		& lua $testSuite
		if ($LASTEXITCODE -ne 0) {
			exit $LASTEXITCODE
		}
	}

	$lintTargets = @($addonFiles) + @($testSuites) + @(
		Get-ChildItem -LiteralPath (Join-Path $projectRoot "tests") -Filter *.lua -File |
			Where-Object { $_.Name -notlike "test_*" } |
			ForEach-Object { "tests/$($_.Name)" }
	)
	& luacheck @lintTargets
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}
finally {
	Pop-Location
}
