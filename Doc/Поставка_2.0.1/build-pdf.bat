@echo off
REM Сборка Руководство_пользователя.pdf (титул — первая страница того же документа)
set DOCDIR=%~dp0
set MAIN=%~dp0..\..\..\main

cd /d "%MAIN%"
python docs\build-pdf.py ^
  --input "%DOCDIR%Руководство_пользователя.md" ^
  --outdir "%DOCDIR%" ^
  --output "Руководство_пользователя" ^
  --version "2.0.1"
pause
