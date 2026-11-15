# Проверка релизного архива DynamoPilot.App.zip. Любое расхождение - исключение (код выхода не ноль).
#
# Проверяется:
#   - структура: файлы лежат в корне архива (так архив ждёт PilotLauncher и «Модули расширения» Pilot);
#   - обязательные файлы: модуль Pilot, рантайм Dynamo, сборки, на которые статически ссылается Dynamo Core,
#     пакет DynamoPilot с узлами и pkg.json;
#   - в архиве нет лишнего: вложенных архивов, временных папок, .pdb в корне, пустых .dll;
#   - архив распаковывается, число файлов и их размеры совпадают с записями архива;
#   - версия DynamoPilot.App.ext2.dll равна -Version (если задана).
#
# Использование: powershell -File build\Test-ReleaseArchive.ps1 -Path <архив> [-Version 1.0.0.8]
param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Version
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path -LiteralPath $Path)) { throw "Нет архива: $Path" }
$Path = (Resolve-Path -LiteralPath $Path).ProviderPath

# Имена записей: PowerShell 5.1 (Compress-Archive) пишет их с обратной косой чертой, PilotLauncher это учитывает.
$zip = [IO.Compression.ZipFile]::OpenRead($Path)
try {
    $files = @($zip.Entries | Where-Object { $_.Name.Length -gt 0 } | ForEach-Object {
        [pscustomobject]@{ Name = $_.FullName.Replace('\', '/'); Length = $_.Length }
    })
}
finally { $zip.Dispose() }

$names = @($files | ForEach-Object { $_.Name })
$errors = New-Object System.Collections.Generic.List[string]

# --- структура ---
$tops = @($names | ForEach-Object { $_.Split('/')[0] } | Select-Object -Unique)
$loose = @($names | Where-Object { $_ -notlike '*/*' })
if ($loose.Count -eq 0) { $errors.Add('В корне архива нет файлов: ожидалась плоская раскладка (файлы модуля прямо в корне).') }
if ($tops.Count -eq 1 -and $loose.Count -eq 0) { $errors.Add("Весь архив лежит в одной папке «$($tops[0])»: ожидались файлы в корне.") }

# --- обязательные файлы ---
$required = @(
    'DynamoPilot.App.ext2.dll', 'DynamoPilot.Data.dll', 'Ascon.Pilot.SDK.dll',
    'DynamoCore.dll', 'DynamoCoreWpf.dll', 'DSCoreNodes.dll', 'CoreNodeModels.dll', 'CoreNodeModelsWpf.dll', 'Greg.dll',
    # на них статически ссылается Dynamo Core: без них DynamoModel не стартует
    'ProtoGeometry.dll', 'LibG.Interface.dll', 'Analytics.NET.Core.dll', 'Analytics.NET.Google.dll', 'Analytics.Net.ADP.dll',
    'UI/Themes/Modern/DynamoModern.xaml',
    'packages/DynamoPilot/pkg.json',
    'packages/DynamoPilot/bin/PilotNodes.dll', 'packages/DynamoPilot/bin/PilotServerNodes.dll', 'packages/DynamoPilot/bin/DynamoPilot.Nodes.dll'
)
foreach ($r in $required) {
    if ($names -notcontains $r) { $errors.Add("В архиве нет обязательного файла: $r") }
}

# --- лишнее ---
foreach ($n in $names) {
    if ($n -like '*.zip') { $errors.Add("Вложенный архив: $n") }
    if ($n -like 'TempArchive/*' -or $n -like 'TestExtract/*') { $errors.Add("Временная папка сборки попала в архив: $n") }
    if ($n -notlike '*/*' -and $n -like '*.pdb') { $errors.Add("В корне архива .pdb: $n") }
}
# Пустые .dll - признак сломанного копирования. System.Windows.Interactivity.dll пуст уже в копии Dynamo из lib и в прежних релизах.
$emptyAllowed = @('System.Windows.Interactivity.dll')
foreach ($f in $files) {
    if ($f.Length -eq 0 -and $f.Name -like '*.dll' -and $emptyAllowed -notcontains $f.Name) { $errors.Add("Пустой файл: $($f.Name)") }
}

# --- распаковка и сверка ---
$temp = Join-Path ([IO.Path]::GetTempPath()) ('dynamopilot-archive-' + [guid]::NewGuid().ToString('N'))
try {
    [IO.Compression.ZipFile]::ExtractToDirectory($Path, $temp)
    $extracted = @(Get-ChildItem -LiteralPath $temp -Recurse -File -Force)
    if ($extracted.Count -ne $files.Count) { $errors.Add("Распаковано файлов $($extracted.Count), в архиве записей $($files.Count).") }
    $sizeZip = ($files | Measure-Object Length -Sum).Sum
    $sizeDisk = ($extracted | Measure-Object Length -Sum).Sum
    if ($sizeZip -ne $sizeDisk) { $errors.Add("Размер после распаковки $sizeDisk байт, по записям архива $sizeZip.") }

    $dll = Join-Path $temp 'DynamoPilot.App.ext2.dll'
    if (Test-Path -LiteralPath $dll) {
        $actual = [Reflection.AssemblyName]::GetAssemblyName($dll).Version.ToString()
        Write-Host "Версия DynamoPilot.App.ext2.dll: $actual"
        if ($Version -and $actual -ne $Version) { $errors.Add("Версия DynamoPilot.App.ext2.dll $actual, ожидалась $Version.") }
    }
    $pkg = Join-Path $temp 'packages/DynamoPilot/pkg.json'
    if (Test-Path -LiteralPath $pkg) {
        try { $null = Get-Content -LiteralPath $pkg -Raw -Encoding UTF8 | ConvertFrom-Json }
        catch { $errors.Add("pkg.json не читается как JSON: $($_.Exception.Message)") }
    }
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}

$size = (Get-Item -LiteralPath $Path).Length
$hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("Архив: {0}`nФайлов: {1}, размер {2:N0} байт`nSHA-256: {3}" -f $Path, $files.Count, $size, $hash)

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "ОШИБКА: $_" }
    throw "Проверка архива не пройдена: $($errors.Count) замечаний."
}
Write-Host 'Проверка архива пройдена.'
