# Release-сборка DynamoPilot и релизный архив src/DynamoPilot.App/bin/Release/net481/DynamoPilot.App.zip.
#
# Архив собирает таргет CreateZip в src/DynamoPilot.App/DynamoPilot.App.csproj, но только если к этому
# моменту уже есть PilotNodes.dll из DynamoPilot.Zero. В решении проект App собирается раньше Zero,
# поэтому за один проход архива нет: второй проход собирает только App и создаёт архив.
#
# Использование: powershell -File build\Build-Release.ps1
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$solution = Join-Path $root 'src\DynamoPilot.App\DynamoPilot.App.sln'
$app = Join-Path $root 'src\DynamoPilot.App\DynamoPilot.App.csproj'
$zip = Join-Path $root 'src\DynamoPilot.App\bin\Release\net481\DynamoPilot.App.zip'

# Старый архив не должен сойти за свежий.
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }

dotnet build $solution -c Release
if ($LASTEXITCODE -ne 0) { throw "dotnet build решения завершился с кодом $LASTEXITCODE" }

dotnet build $app -c Release --no-dependencies
if ($LASTEXITCODE -ne 0) { throw "dotnet build DynamoPilot.App завершился с кодом $LASTEXITCODE" }

if (-not (Test-Path -LiteralPath $zip)) { throw "Архив не создан: $zip" }
Write-Host "Архив: $zip"
