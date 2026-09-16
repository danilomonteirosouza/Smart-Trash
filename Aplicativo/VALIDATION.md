# Validação — v1.1.0+4

## Validações realizadas no pacote

- Estrutura do ZIP e arquivos obrigatórios.
- YAML do `pubspec.yaml` e `analysis_options.yaml`.
- JSON de todos os Lotties locais.
- XML Android/iOS principal.
- Imports Dart locais.
- Presença do ícone próprio e assets de branding.
- Splash nativa verde integrada ao primeiro frame Flutter.
- `runApp()` chamado antes da inicialização assíncrona do banco/controlador.
- Câmera sem inicialização automática em `initState`.
- HiveMQ removido do HUB e mantido em Configurações.
- Telas dedicadas para todas as leituras principais.

## Validação que deve ser executada no Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_windows.ps1
```

O bootstrap executa `flutter pub get`, `flutter analyze` e `flutter test`. Use `-BuildApk` para também gerar o APK debug.
