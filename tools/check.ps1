$projectRoot = Split-Path -Parent $PSScriptRoot
$addonFiles = @(
	"Init.lua",
	"Threat.lua",
	"Nameplates.lua",
	"Config.lua"
)

Push-Location $projectRoot
try {
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
