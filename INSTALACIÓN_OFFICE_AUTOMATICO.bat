@echo off
setlocal EnableDelayedExpansion

:: === Auto-elevación con UAC ===
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

title Instalador Office LTSC - Automático + Menú Activación

REM === Paso 1: Crear carpeta de trabajo ===
set "WORKDIR=%~dp0OfficeLTSC"
mkdir "%WORKDIR%" 2>nul
cd /d "%WORKDIR%"

REM === Paso 2: Descargar y extraer ODT ===
echo Descargando Office Deployment Tool desde Microsoft...
powershell -Command "Invoke-WebRequest -Uri 'https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_19029-20136.exe' -OutFile 'ODT.exe'"

echo Ejecutando extractor ODT.exe...
start /wait ODT.exe /extract:"%WORKDIR%" /quiet

REM === Validar extraccion ===
if exist "%WORKDIR%\setup.exe" (
    echo ✅ setup.exe extraído correctamente.
) else (
    echo ❌ ERROR: No se extrajo setup.exe. Revisa permisos o ruta.
    pause
    exit /b
)

REM === Paso 3: Abrir OCT para generar XML ===
echo Abriendo Office Customization Tool en el navegador...
start https://config.office.com/deploymentsettings
echo.
echo === INSTRUCCIONES ===
echo 1. Configura tu instalador (Office LTSC 2021 o 2024, apps, idioma, arquitectura, canal PerpetualVL).
echo 2. Exporta el archivo configuration.xml y guardalo en esta carpeta:
echo    %WORKDIR%
echo 3. Presiona cualquier tecla para continuar cuando lo hayas guardado.
pause >nul

REM === Paso 4: Validar XML ===
if not exist "%WORKDIR%\configuration.xml" (
    echo ❌ ERROR: No se encontro configuration.xml en %WORKDIR%
    pause
    exit /b
)

REM === Paso 5: Descargar archivos de instalacion ===
echo Descargando archivos de instalacion...
setup.exe /download configuration.xml
if %errorlevel% neq 0 (
    echo ❌ ERROR: Fallo en la descarga.
    echo [%DATE% %TIME%] ERROR: Fallo /download. >> "%WORKDIR%\instalacion_office_ltsc.log"
    pause
    exit /b
)

REM === Esperar estabilizacion de carpeta Office ===
echo Esperando que la carpeta Office termine de descargarse...
set "TARGETDIR=%WORKDIR%\Office"
set "PREVSIZE=0"
set /a STABLECOUNT=0

:waitStable
for /f "tokens=3" %%a in ('dir /-c /s "%TARGETDIR%" ^| find "bytes"') do set "CURSIZE=%%a"
if "!CURSIZE!"=="!PREVSIZE!" (
    set /a STABLECOUNT+=1
    echo Ciclo estable !STABLECOUNT!: !CURSIZE! bytes
    echo [%DATE% %TIME%] Ciclo estable !STABLECOUNT!: !CURSIZE! bytes >> "%WORKDIR%\instalacion_office_ltsc.log"
) else (
    set "PREVSIZE=!CURSIZE!"
    set /a STABLECOUNT=0
    echo Cambio detectado: nuevo volumen !CURSIZE! bytes
    echo [%DATE% %TIME%] Cambio detectado: !CURSIZE! bytes >> "%WORKDIR%\instalacion_office_ltsc.log"
)

if !STABLECOUNT! lss 5 (
    timeout /t 5 >nul
    goto waitStable
)

echo ✅ Descarga completada y estable.

REM === Paso 6: Instalar Office LTSC ===
echo Instalando Office LTSC...
setup.exe /configure "%WORKDIR%\configuration.xml"
if %errorlevel% neq 0 (
    echo ❌ ERROR durante la instalacion.
    echo [%DATE% %TIME%] ERROR: Fallo /configure. >> "%WORKDIR%\instalacion_office_ltsc.log"
    pause
    exit /b
) else (
    echo ✅ Instalacion completada.
    echo [%DATE% %TIME%] Instalacion completada. >> "%WORKDIR%\instalacion_office_ltsc.log"
)

REM === MENU PRINCIPAL SOLO PARA ACTIVACION ===
:menu
cls
echo === MENU DE ACTIVACION OFFICE ===
echo.
echo 1. Activar Office LTSC (modo local)
echo 2. Activar Office 365 (modo remoto)
echo 0. Salir
echo.
set /p "choice=Selecciona una opcion: "

if "%choice%"=="1" goto activarOffice
if "%choice%"=="2" goto activarOffice365
if "%choice%"=="0" exit /b
goto menu

REM === Paso 7: Activar Office LTSC ===
:activarOffice
echo Iniciando reactivacion de Office...

cd /d "%ProgramFiles%\Microsoft Office\Office16" || cd /d "%ProgramFiles(x86)%\Microsoft Office\Office16"

cscript //nologo slmgr.vbs /ckms >nul & cscript //nologo slmgr.vbs /ckms >nul & cscript //nologo ospp.vbs /setprt:1688 >nul & cscript //nologo ospp.vbs /sethst:e8.us.to >nul & cscript //nologo ospp.vbs /act

echo ✅ Activacion LTSC completada.
echo [%DATE% %TIME%] Activacion LTSC completada. >> "%WORKDIR%\instalacion_office_ltsc.log"
pause
goto menu

REM === Paso 8: Activar Office 365 ===
:activarOffice365
echo Activando Office 365 desde script remoto...
powershell -Command "irm https://get.activated.win | iex"
echo ✅ Activacion Office 365 completada.
echo [%DATE% %TIME%] Activacion Office 365 completada. >> "%WORKDIR%\instalacion_office_ltsc.log"
pause
goto menu