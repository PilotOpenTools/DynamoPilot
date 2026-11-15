# Разработка

## Состав решения

Решение `src/DynamoPilot.App/DynamoPilot.App.sln` собирает пять проектов (все на .NET Framework 4.8.1):

| Проект | Сборка | Назначение |
|---|---|---|
| `src/DynamoPilot.App` | `DynamoPilot.App.ext2.dll` | модуль расширения Pilot: пункт меню «DynamoPilot», запуск `DynamoModel` и окна Dynamo внутри клиента |
| `src/DynamoPilot.Zero` | `PilotNodes.dll` | узлы Dynamo (ZeroTouch) для объектов Pilot |
| `src/DynamoPilot.Nodes` | `DynamoPilot.Nodes.dll` | узлы со своим интерфейсом, например выбор документов |
| `src/DynamoPilot.Server` | `PilotServerNodes.dll` | узлы Server API |
| `src/DynamoPilot.Data` | `DynamoPilot.Data.dll` | общие обёртки над Pilot SDK |

Узлы (`PilotNodes.dll`, `PilotServerNodes.dll`, `DynamoPilot.Nodes.dll`) попадают в пакет Dynamo `packages/DynamoPilot` вместе с `pkg.json` (источник: `src/DynamoPilot.Nodes/pkg.json`). При запуске Dynamo в клиенте модуль копирует этот пакет в `%APPDATA%\Dynamo\Dynamo Core\2.16\packages` (один раз за сеанс клиента).

Рантайм Dynamo Core 2.16.4 лежит в `lib/DynamoCoreRuntime2.16.4` и целиком входит в релизный архив, чтобы модуль работал без отдельной установки Dynamo и без интернета. О составе и лицензиях этой папки см. раздел «Сторонние компоненты» в [README](../README.md).

Пакеты NuGet: `Ascon.Pilot.SDK` 26.11.2, `DynamoVisualProgramming.Core` и `WpfUILibrary` 2.16.4.10216.

## Требования

- Windows и .NET SDK (в CI используется 10.0), а также пакет разработчика .NET Framework 4.8.1 (есть в Visual Studio 2022).
- Для проверки в клиенте: Pilot-ICE Enterprise или Pilot-BIM.

## Сборка

```powershell
dotnet build src\DynamoPilot.App\DynamoPilot.App.sln -c Debug
```

Сборка Debug проекта `DynamoPilot.App` после сборки копирует результат в папки `Development` клиентов, если они есть (создаёт их при отсутствии):

- `%LOCALAPPDATA%\ASCON\Pilot-BIM\Development\DynamoPilot.App`
- `%LOCALAPPDATA%\ASCON\Pilot-ICE Enterprise\Development\DynamoPilot.App`

Туда же попадают рантайм Dynamo из `lib` и пакет `packages\DynamoPilot` с узлами из проектов `Zero`, `Nodes` и `Server`. Закройте клиент перед сборкой: открытые файлы не перезаписываются. Затем запустите клиент и выберите пункт «DynamoPilot» в главном меню.

Известная проблема: цель копирования в Debug берёт `src\DynamoPilot.Zero\bin\Debug\net481\PilotNodes.xml`, а `Zero` создаёт этот файл с документацией только в Release. В чистом клоне Debug-сборка решения падает с ошибкой MSB3030 (проверено на клоне без `bin` и `obj`, повторная сборка её не исправляет). Release-сборка этим не затронута.

Проект `DynamoPilot.App` в Debug по умолчанию запускает `C:\Program Files\ASCON\Pilot-ICE Enterprise\Ascon.Pilot.PilotEnterprise.exe`.

## Релизная сборка

```powershell
powershell -File build\Build-Release.ps1
powershell -File build\Test-ReleaseArchive.ps1 -Path src\DynamoPilot.App\bin\Release\net481\DynamoPilot.App.zip
```

Подробности и порядок выпуска версии: [releasing.md](releasing.md).

## Проверка изменений

Автоматических тестов в репозитории нет: узлам нужен живой клиент Pilot. Перед PR соберите решение (Release обязательно, Debug — с учётом известной проблемы выше), проверьте релизный архив скриптом выше и откройте Dynamo в клиенте. Для узлов, работающих с базой, запустите граф из папки `Samples`, который их использует. Граф «Создание заданий» создаёт задания, запускайте его только на тестовой базе.

CI (`.github/workflows/ci.yml`) на каждый PR собирает решение в Release и проверяет релизный архив.
