@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo  LIXEIRA INTELIGENTE - INSTALACAO + VALIDACAO + APK DEBUG
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tool\bootstrap_windows.ps1" -BuildApk
set EXIT_CODE=%ERRORLEVEL%
if not "%EXIT_CODE%"=="0" (
  echo.
  echo O processo terminou com erro %EXIT_CODE%.
  echo Consulte QUICK_START.txt e a mensagem acima.
  pause
  exit /b %EXIT_CODE%
)
echo.
echo Processo concluido com sucesso.
echo APK: build\app\outputs\flutter-apk\app-debug.apk
pause
endlocal
