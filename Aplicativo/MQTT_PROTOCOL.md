# Contrato MQTT v1

## Telemetria — `lixeira/telemetry`
```json
{"type":"telemetry","deviceId":"LIXEIRA-01","weightGrams":182.4,"metalDetected":true,"presence":true,"fillLevel":64.0,"distanceCm":19.4,"gate":"closed","network":"wifi","rssi":-57,"uptimeMs":12345}
```

## Comando — `lixeira/command`
```json
{"type":"command","deviceId":"LIXEIRA-01","commandId":"uuid-v4","action":"open"}
```
Ações: `open`, `close`, `ping`.

## ACK — `lixeira/ack`
```json
{"type":"ack","deviceId":"LIXEIRA-01","commandId":"uuid-v4","action":"open","status":"ok","detail":"comporta aberta","network":"wifi"}
```

## Status — `lixeira/status`
Retained no broker para refletir o último estado conhecido.
