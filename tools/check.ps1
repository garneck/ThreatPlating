$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$addonFiles = @(
	"Init.lua",
	"Threat.lua",
	"Display.lua",
	"Nameplates.lua",
	"Config.lua"
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

	foreach ($addonFile in $addonFiles) {
		& luac -p $addonFile
		if ($LASTEXITCODE -ne 0) {
			exit $LASTEXITCODE
		}
	}

	& lua tests/test_threat.lua
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	& lua tests/test_database.lua
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	& lua tests/test_runtime.lua
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	& lua tests/test_raid.lua
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	& luacheck @addonFiles tests/test_threat.lua tests/test_database.lua tests/test_runtime.lua tests/test_raid.lua tests/wow_mock.lua
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}
finally {
	Pop-Location
}
