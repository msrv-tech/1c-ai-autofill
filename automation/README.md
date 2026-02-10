# Автоматизация сборки 1C AI Autofill

Скрипт для сборки расширения из XML, загрузки в конфигурацию и обновления БД.

## Требования

- 1С:Предприятие 8.3 (Designer)
- База с конфигурацией, к которой можно подключить расширение (УНФ, Розница, УТ, КА, ERP)

## Быстрый старт

```powershell
# Полный цикл: собрать .cfe из xml → загрузить → обновить БД → запустить 1С
.\update-extension-and-run-db.ps1 -BuildFromXml

# Только собрать .cfe без загрузки в БД (для релиза)
.\update-extension-and-run-db.ps1 -BuildFromXml -SkipLoadExtension -SkipDbUpdate -SkipRunClient
```

## Параметры

| Параметр | По умолчанию | Описание |
|----------|--------------|----------|
| `-PlatformExe` | Путь к 1cv8.exe | Исполняемый файл платформы |
| `-ConnectionString` | Из .env или файловая база | Строка подключения к информационной базе |
| `-XmlPath` | `../xml` | Каталог XML-выгрузки расширения |
| `-ExtensionCfePath` | `../bin/GPT_ОписаниеНоменклатуры.cfe` | Путь для сохранения .cfe |
| `-ExtensionName` | `GPT_ОписаниеНоменклатуры` | Имя расширения в конфигурации |
| `-BuildFromXml` | — | Собрать .cfe из каталога xml |
| `-SkipLoadExtension` | — | Не загружать .cfe в конфигурацию |
| `-SkipDbUpdate` | — | Не обновлять конфигурацию БД |
| `-SkipRunClient` | — | Не запускать 1С:Предприятие |
| `-Wait` | — | Ждать закрытия клиента 1С |

## Конфигурация (.env)

Создайте файл `.env` в корне worktree (рядом с `xml/`):

```
1C_CONNECTION_STRING=File="D:\path\to\your\base";
1C_PLATFORM_EXE=C:\Program Files\1cv8\8.3.27.1859\bin\1cv8.exe
```

- `1C_CONNECTION_STRING` — строка подключения к информационной базе.
- `1C_PLATFORM_EXE` — путь к `1cv8.exe` (платформа 1С). Если не задан, используется значение по умолчанию в скрипте.

## Ветки конфигураций

Для ветки **UNF_Rozn_Fresh** (1cfresh) имя расширения другое:

```powershell
.\update-extension-and-run-db.ps1 -BuildFromXml -ExtensionName "GigaСhat_ОписаниеНоменклатуры" -ExtensionCfePath "..\bin\GigaСhat_ОписаниеНоменклатуры.cfe"
```

Для main, UNF_Rozn, UT_KA_ERP — `GPT_ОписаниеНоменклатуры` по умолчанию.
