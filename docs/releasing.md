# Выпуск версии

Релиз публикует workflow `.github/workflows/release.yml` по тегу из четырёх чисел, как у прошлых релизов (`1.0.0.8`).

## Порядок

1. Поднимите `AssemblyVersion` в `src/DynamoPilot.App/DynamoPilot.App.csproj` и закоммитьте. Версия узлов (`0.0.0.2` в проектах `Zero`, `Nodes`, `Server`, `Data`) и `version` в `pkg.json` с версией релиза не связаны.
2. Создайте аннотированный тег. Его текст станет описанием релиза (у лёгкого тега берётся сообщение коммита):

   ```powershell
   git tag -a 1.0.0.9 -m "- что изменилось"
   git push origin 1.0.0.9
   ```

3. Workflow запустится на теге и выполнит:
   - проверку, что тег равен `AssemblyVersion` из `DynamoPilot.App.csproj`;
   - Release-сборку решения и создание `DynamoPilot.App.zip` (`build/Build-Release.ps1`);
   - проверку архива (`build/Test-ReleaseArchive.ps1`);
   - расчёт `SHA256SUMS.txt`;
   - публикацию релиза `DynamoPilot <версия>` с двумя файлами.

Если проверка не прошла, релиз не создаётся: исправьте причину, удалите тег (`git push --delete origin 1.0.0.9` и `git tag -d 1.0.0.9`) и повторите с тем же номером.

## Что в релизе

- `DynamoPilot.App.zip` — файлы модуля прямо в корне архива. Под этим именем его ищет PilotLauncher, менять его нельзя. Архив ставится «Модули расширения → Создать → Расширение» на сервере или распаковывается в `Development` клиента, интернет не нужен.
- `SHA256SUMS.txt` — контрольная сумма архива в формате `sha256sum`. GitHub сам считает такую сумму для файла релиза, PilotLauncher сверяет её при установке.

## Проверка архива

`build/Test-ReleaseArchive.ps1` проверяет:

- файлы лежат в корне архива, а не в одной вложенной папке;
- на месте модуль `DynamoPilot.App.ext2.dll`, рантайм Dynamo, сборки, на которые статически ссылается Dynamo Core (`ProtoGeometry`, `LibG.Interface`, `Analytics.*`), и пакет `packages/DynamoPilot` с узлами и `pkg.json`;
- в архиве нет вложенных архивов, временных папок, `.pdb` в корне и пустых `.dll` (кроме `System.Windows.Interactivity.dll`, который пуст уже в рантайме из `lib`);
- архив распаковывается, а число и размер файлов совпадают с записями архива;
- версия `DynamoPilot.App.ext2.dll` совпадает с `-Version`, если параметр задан;
- `pkg.json` читается как JSON.

Запуск на своей машине:

```powershell
powershell -File build\Build-Release.ps1
powershell -File build\Test-ReleaseArchive.ps1 -Path src\DynamoPilot.App\bin\Release\net481\DynamoPilot.App.zip -Version 1.0.0.9
```

## Особенности сборки архива

- Архив создаёт цель `CreateZip` в `DynamoPilot.App.csproj`, но только если уже собран `PilotNodes.dll`. В решении проект `App` собирается раньше `Zero`, поэтому `Build-Release.ps1` собирает решение, а затем второй раз только `DynamoPilot.App` (`--no-dependencies`).
- Архив делает `Compress-Archive` из Windows PowerShell 5.1: имена записей в нём с обратной косой чертой. PilotLauncher и Pilot это читают, как и в прежних релизах. Скрипт проверки приводит имена к одному виду.
- Релиз должен быть обычным (не черновиком и не pre-release): PilotLauncher берёт последний через `releases/latest`.
