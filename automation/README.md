# Автоматизация сборки 1C AI Autofill

Скрипты для сборки расширения из XML, загрузки в конфигурацию и обновления БД.

## Требования

- 1С:Предприятие 8.3 (Designer)
- Базы с конфигурациями под каждую ветку: УНФ/Розница, УТ/КА/ERP, 1С:Фреш

## Сборка по веткам (рекомендуется)

```powershell
# Собрать ветку UNF_Rozn на своей базе
.\build-for-branch.ps1 -Branch UNF_Rozn -BuildFromXml

# Собрать UNF_Rozn_Fresh без запуска 1С (для релиза)
.\build-for-branch.ps1 -Branch UNF_Rozn_Fresh -BuildFromXml -SkipRunClient

# Собрать UT_KA_ERP и запустить 1С
.\build-for-branch.ps1 -Branch UT_KA_ERP -BuildFromXml -Wait
```

### Настройка

1. Скопируйте `build-config.example.json` в `build-config.json`.

2. В `.env` добавьте строки подключения для каждой ветки:

```
1C_PLATFORM_EXE=C:\Program Files\1cv8\8.5.1.1150\bin\1cv8.exe

# main (УНФ/Розница)
1C_CONNECTION_STRING=File="D:\1С\bd\ИИУНФ3013";Usr="Администратор";Pwd=

# UNF_Rozn — база УНФ или Розница
1C_CONNECTION_STRING_UNF_Rozn=File="D:\1С\bd\УНФ_Розница";Usr="Администратор";Pwd=

# UNF_Rozn_Fresh — база 1С:Фреш
1C_CONNECTION_STRING_UNF_Rozn_Fresh=File="D:\1С\bd\Фреш";Usr="Администратор";Pwd=

# UT_KA_ERP — база УТ/КА/ERP
1C_CONNECTION_STRING_UT_KA_ERP=File="D:\1С\bd\УТ11";Usr="Администратор";Pwd=
```

3. Worktrees должны быть в `worktrees/main`, `worktrees/UNF_Rozn`, и т.д. — корень определяется автоматически относительно скрипта.

## Прямой вызов (одна ветка)

```powershell
# Полный цикл для текущего worktree (main)
.\update-extension-and-run-db.ps1 -BuildFromXml

# Только собрать .cfe без загрузки в БД
.\update-extension-and-run-db.ps1 -BuildFromXml -SkipLoadExtension -SkipDbUpdate -SkipRunClient
```

## Параметры update-extension-and-run-db.ps1

| Параметр | По умолчанию | Описание |
|----------|--------------|----------|
| `-PlatformExe` | Из .env | Путь к 1cv8.exe |
| `-ConnectionString` | Из .env | Строка подключения к БД |
| `-XmlPath` | `../xml` | Каталог XML-выгрузки |
| `-ExtensionCfePath` | `../bin/...` | Путь для сохранения .cfe |
| `-ExtensionName` | `GPT_ОписаниеНоменклатуры` | Имя расширения (для Fresh: `GigaСhat_ОписаниеНоменклатуры`) |
| `-BuildFromXml` | — | Собрать .cfe из xml |
| `-SkipLoadExtension` | — | Не загружать .cfe в конфигурацию |
| `-SkipDbUpdate` | — | Не обновлять конфигурацию БД |
| `-SkipRunClient` | — | Не запускать 1С:Предприятие |
| `-Wait` | — | Ждать закрытия клиента 1С |

## Маппинг ветка → конфигурация

| Ветка | Имя расширения | База |
|-------|----------------|------|
| main | GPT_ОписаниеНоменклатуры | УНФ/Розница |
| UNF_Rozn | GPT_ОписаниеНоменклатуры | УНФ/Розница |
| UNF_Rozn_Fresh | GigaСhat_ОписаниеНоменклатуры | 1С:Фреш |
| UT_KA_ERP | GPT_ОписаниеНоменклатуры | УТ/КА/ERP |
