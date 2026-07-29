$projectRoot = Split-Path -Parent $PSScriptRoot
$addonFiles = @(
	"Init.lua",
	"Threat.lua",
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

Push-Location $projectRoot
try {
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

	& lua tests/test_runtime.lua
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}

	& luacheck @addonFiles tests/test_threat.lua
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
}
finally {
	Pop-Location
}
