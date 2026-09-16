# Lixeira Inteligente — Aplicativo Flutter

Versão **1.1.0+4** baseada na versão funcional 1.0.2+3, com evolução visual e de experiência.

## Destaques desta versão

- Splash nativa integrada visualmente à Splash Flutter, evitando a tela padrão anterior.
- Splash animada com motion design e duração mínima de 3,6 s.
- HUB inicial com cards animados e cores por tipo de leitura.
- Telas dedicadas para peso, nível, presença, metal, comporta e conectividade.
- IA com câmera sob demanda: a câmera somente é aberta após o botão **Iniciar análise por câmera**.
- HiveMQ configurado exclusivamente em **Configurações**; o HUB mostra apenas status.
- Histórico com filtros e motion design.
- Ícone próprio da Lixeira Inteligente para Android/iOS.
- Assets Lottie locais, sem dependência de Internet para animações.
- SQLite, MQTT/HiveMQ TLS, armazenamento seguro e protocolo com ESP32 preservados.

## Quick Start — Windows

Na pasta `Aplicativo`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_windows.ps1
```

Para preparar, validar e gerar APK debug:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\bootstrap_windows.ps1 -BuildApk
```

APK esperado:

`build\app\outputs\flutter-apk\app-debug.apk`

## Teste recomendado

1. Execute o bootstrap.
2. Configure o HiveMQ somente na aba **Config.**.
3. Valide o status no HUB.
4. Publique telemetria no tópico configurado.
5. Abra cada card do HUB e confira a tela dedicada.
6. Abra **IA** e confirme que a câmera não inicia automaticamente.
7. Pressione **Iniciar análise por câmera** e teste a captura.
8. Teste Abrir/Fechar na tela dedicada da comporta.
