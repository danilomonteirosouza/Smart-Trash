param(
  [switch]$BuildApk,
  [switch]$SkipAnalyze,
  [switch]$SkipTests,
  [switch]$RepairPlatforms,
  [switch]$SkipAndroidLicenses
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Evita caracteres corrompidos no PowerShell/console do Windows.
try { chcp 65001 > $null } catch {}
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $Utf8NoBom
[Console]::OutputEncoding = $Utf8NoBom
$OutputEncoding = $Utf8NoBom

function Invoke-CheckedCommand {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name falhou com codigo de saida $LASTEXITCODE. O bootstrap foi interrompido para evitar uma falsa mensagem de sucesso."
  }
}

function Invoke-NativeCapture {
  param(
    [Parameter(Mandatory = $true)][string]$FileName,
    [string]$Arguments = ""
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  if ($FileName.ToLowerInvariant().EndsWith(".bat") -or $FileName.ToLowerInvariant().EndsWith(".cmd")) {
    $psi.FileName = $env:ComSpec
    $escaped = '"' + $FileName + '" ' + $Arguments
    $psi.Arguments = '/d /c "' + $escaped + '"'
  } else {
    $psi.FileName = $FileName
    $psi.Arguments = $Arguments
  }
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $psi
  try {
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [PSCustomObject]@{
      ExitCode = $process.ExitCode
      Output = ((@($stdout, $stderr) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n")
    }
  }
  finally {
    $process.Dispose()
  }
}

function Get-JavaMajorVersion {
  param([Parameter(Mandatory = $true)][string]$JdkHome)

  $javaExe = Join-Path $JdkHome "bin\java.exe"
  if (-not (Test-Path $javaExe)) { return $null }

  $result = Invoke-NativeCapture -FileName $javaExe -Arguments "-version"
  if ($result.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($result.Output)) { return $null }

  $firstLine = [string](($result.Output -split "`r?`n") | Select-Object -First 1)
  if ($firstLine -match 'version "(?<major>\d+)') {
    return [int]$Matches['major']
  }
  return $null
}

function Add-JdkCandidate {
  param(
    [System.Collections.Generic.List[string]]$Candidates,
    [string]$Path
  )

  if ([string]::IsNullOrWhiteSpace($Path)) { return }
  if (Test-Path $Path) {
    $resolved = (Resolve-Path $Path).Path
    if (-not $Candidates.Contains($resolved)) { $Candidates.Add($resolved) }
  }
}

function Resolve-CompatibleJdk {
  $candidates = [System.Collections.Generic.List[string]]::new()

  Add-JdkCandidate $candidates $env:JAVA_HOME

  $javaCommand = Get-Command java -ErrorAction SilentlyContinue
  if ($null -ne $javaCommand -and -not [string]::IsNullOrWhiteSpace($javaCommand.Source)) {
    $javaBin = Split-Path -Parent $javaCommand.Source
    Add-JdkCandidate $candidates (Split-Path -Parent $javaBin)
  }

  Add-JdkCandidate $candidates "C:\Program Files\Android\Android Studio\jbr"

  $roots = @(
    "C:\Program Files\Eclipse Adoptium",
    "C:\Program Files\Microsoft",
    "C:\Program Files\Java"
  )

  foreach ($rootPath in $roots) {
    if (Test-Path $rootPath) {
      Get-ChildItem -Path $rootPath -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object { Add-JdkCandidate $candidates $_.FullName }
    }
  }

  foreach ($candidate in $candidates) {
    $major = Get-JavaMajorVersion $candidate
    if ($null -ne $major -and $major -ge 17 -and $major -lt 26) {
      return [PSCustomObject]@{ Home = $candidate; Major = $major }
    }
  }

  return $null
}

function Assert-FlutterAndDart {
  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  if ($null -eq $flutterCommand) {
    throw "Flutter nao foi encontrado no PATH. Instale o Flutter Stable 3.47+ e abra um novo PowerShell. Consulte QUICK_START.txt."
  }

  $dartCommand = Get-Command dart -ErrorAction SilentlyContinue
  if ($null -eq $dartCommand) {
    throw "Dart nao foi encontrado no PATH. A instalacao do Flutter deve fornecer o Dart. Verifique o PATH do Flutter."
  }

  $flutterInfo = Invoke-NativeCapture -FileName $flutterCommand.Source -Arguments "--version"
  if ($flutterInfo.ExitCode -ne 0) { throw "Nao foi possivel executar flutter --version." }
  if ($flutterInfo.Output -match 'Flutter\s+(?<version>\d+\.\d+\.\d+)') {
    $flutterVersion = [version]$Matches['version']
    if ($flutterVersion -lt [version]'3.47.0') {
      throw "Flutter $flutterVersion detectado. Este projeto requer Flutter 3.47.0 ou superior. Execute: flutter upgrade"
    }
  }

  $dartInfo = Invoke-NativeCapture -FileName $dartCommand.Source -Arguments "--version"
  if ($dartInfo.ExitCode -ne 0) { throw "Nao foi possivel executar dart --version." }
  if ($dartInfo.Output -match 'Dart SDK version:\s*(?<version>\d+\.\d+\.\d+)') {
    $dartVersion = [version]$Matches['version']
    if ($dartVersion -lt [version]'3.12.0') {
      throw "Dart $dartVersion detectado. Este projeto requer Dart 3.12.0 ou superior. Atualize o Flutter Stable."
    }
  }

  Write-Host "[preflight] Flutter/Dart encontrados."
  Write-Host ($flutterInfo.Output.Trim())
}

function Repair-NativePlatformsIfNeeded {
  param([switch]$Force)

  $androidMissing = -not (Test-Path ".\android\app")
  $iosMissing = -not (Test-Path ".\ios\Runner")
  if (-not $Force -and -not $androidMissing -and -not $iosMissing) {
    Write-Host "[3/9] Plataformas Android/iOS ja existem; regeneracao nao e necessaria."
    return
  }

  Write-Host "[3/9] Reparando plataformas nativas Android/iOS..."
  $backup = Join-Path $env:TEMP ("lixeira_bootstrap_" + $PID)
  try {
    New-Item -ItemType Directory -Force -Path $backup | Out-Null
    foreach ($item in @("lib", "test", "assets", "tool")) {
      if (Test-Path ".\$item") { Copy-Item -Recurse -Force ".\$item" (Join-Path $backup $item) }
    }
    foreach ($file in @("pubspec.yaml", "analysis_options.yaml", "README.md", "QUICK_START.txt", "VALIDATION.md", "MQTT_PROTOCOL.md", "INSTALAR_WINDOWS.cmd")) {
      if (Test-Path ".\$file") { Copy-Item -Force ".\$file" (Join-Path $backup $file) }
    }

    Invoke-CheckedCommand -Name "flutter create" -Command {
      flutter create --project-name lixeira_inteligente --org br.edu.ete --platforms=android,ios .
    }

    foreach ($item in @("lib", "test", "assets", "tool")) {
      $source = Join-Path $backup $item
      if (Test-Path $source) {
        Remove-Item -Recurse -Force ".\$item" -ErrorAction SilentlyContinue
        Copy-Item -Recurse -Force $source ".\$item"
      }
    }
    foreach ($file in @("pubspec.yaml", "analysis_options.yaml", "README.md", "QUICK_START.txt", "VALIDATION.md", "MQTT_PROTOCOL.md", "INSTALAR_WINDOWS.cmd")) {
      $source = Join-Path $backup $file
      if (Test-Path $source) { Copy-Item -Force $source ".\$file" }
    }
  }
  finally {
    if (Test-Path $backup) { Remove-Item -Recurse -Force $backup -ErrorAction SilentlyContinue }
  }
}

Write-Host "============================================================"
Write-Host " LIXEIRA INTELIGENTE 1.1.1+5 - QUICK START WINDOWS"
Write-Host "============================================================"

Assert-FlutterAndDart

$jdk = Resolve-CompatibleJdk
if ($null -eq $jdk) {
  throw "Nenhum JDK compativel foi encontrado. Instale JDK 17 ou 21 (Java >=17 e <26) ou Android Studio com JBR e execute novamente."
}

$env:JAVA_HOME = $jdk.Home
$jdkBin = Join-Path $jdk.Home "bin"
if (-not (($env:Path -split ';') -contains $jdkBin)) { $env:Path = "$jdkBin;$env:Path" }

Write-Host "[preflight] JDK $($jdk.Major) selecionado: $($jdk.Home)"
Invoke-CheckedCommand -Name "flutter config --jdk-dir" -Command { flutter config --jdk-dir "$($jdk.Home)" }

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "[1/9] Executando flutter doctor..."
Invoke-CheckedCommand -Name "flutter doctor" -Command { flutter doctor }

Write-Host "[2/9] Verificando licencas do Android SDK..."
if ($SkipAndroidLicenses) {
  Write-Host "Verificacao/aceite interativo ignorado por -SkipAndroidLicenses."
} else {
  Write-Host "Se houver licencas pendentes, responda Y quando o Android SDK solicitar."
  Invoke-CheckedCommand -Name "flutter doctor --android-licenses" -Command {
    flutter doctor --android-licenses
  }
}

Repair-NativePlatformsIfNeeded -Force:$RepairPlatforms

Write-Host "[4/9] Limpando artefatos anteriores..."
Invoke-CheckedCommand -Name "flutter clean" -Command { flutter clean }

Write-Host "[5/9] Instalando dependencias Flutter/Dart..."
Invoke-CheckedCommand -Name "flutter pub get" -Command { flutter pub get }

Write-Host "[6/9] Aplicando permissoes, IDs e requisitos nativos..."
Invoke-CheckedCommand -Name "configure_platforms.dart" -Command { dart run .\tool\configure_platforms.dart }

Write-Host "[7/9] Rodando analise estatica..."
if ($SkipAnalyze) {
  Write-Host "Analise estatica ignorada por -SkipAnalyze."
} else {
  Invoke-CheckedCommand -Name "flutter analyze" -Command { flutter analyze }
}

Write-Host "[8/9] Rodando testes..."
if ($SkipTests) {
  Write-Host "Testes ignorados por -SkipTests."
} else {
  Invoke-CheckedCommand -Name "flutter test" -Command { flutter test }
}

Write-Host "[9/9] Finalizacao..."
if ($BuildApk) {
  Write-Host "Gerando APK debug..."
  Invoke-CheckedCommand -Name "flutter build apk --debug" -Command { flutter build apk --debug }
  Write-Host "APK: $root\build\app\outputs\flutter-apk\app-debug.apk"
} else {
  Write-Host "Build de APK nao solicitado. Para gerar:"
  Write-Host "powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_windows.ps1 -BuildApk"
}

Write-Host ""
Write-Host "Dispositivos detectados:"
& flutter devices
Write-Host ""
Write-Host "Lixeira Inteligente preparada e validada."
Write-Host "Para iniciar no celular/emulador: flutter run"
