/**
 * LIXEIRA INTELIGENTE — NodeMCU V3 ESP8266 (ESP-12E / CH340) | Wi-Fi MQTT TLS
 * Integracao com Flutter -> HiveMQ Cloud -> servo da tampa
 * DIAGNOSTICO: logs detalhados na Serial (115200 baud); heartbeat a cada 10 s.
 * Servo: primeiro pulso PWM usa o destino do comando, nao o neutro padrao (90 graus).
 *
 * Comandos do Flutter (JSON, QoS 1, sem retained):
 * {"type":"command","deviceId":"LIXEIRA-01","commandId":"uuid","action":"open"}
 * {"type":"command","deviceId":"LIXEIRA-01","commandId":"uuid","action":"close"}
 *
 * Requisitos: placa ESP8266 (core 3.x), bibliotecas PubSubClient e ArduinoJson (6 ou 7).
 * A biblioteca Servo é incluída no core ESP8266.
 * O Wi-Fi foi recuperado do exemplo .ino; os dados HiveMQ e o protocolo vêm do Flutter.
 * TLS valida o servidor com CA ISRG Root X1 (sem setInsecure).
 *
 * NÃO usa ESP32Servo.h: este arquivo é para ESP8266.
 */
#include <Arduino.h>
#include <ESP8266WiFi.h>
#include <WiFiClientSecureBearSSL.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Servo.h>
#include <time.h>

// ------------------------------------------------------
// AJUSTES DO PROJETO
// ------------------------------------------------------
static const char *WIFI_SSID = "";
static const char *WIFI_PASSWORD = "";

static const char *MQTT_HOST = "e7c5887cdd5b438d8f9f659b828adef8.s1.eu.hivemq.cloud";
static const uint16_t MQTT_PORT = 8883;
static const char *MQTT_USERNAME = "lixeira_aluno";
static const char *MQTT_PASSWORD = "Vilarim/123";
static const char *MQTT_TOPIC = "lixeira_inteligente";
static const char *DEVICE_ID = "LIXEIRA-01";

static const uint8_t SERVO_PIN = D5; // D5 = GPIO14, NodeMCU ESP8266
static const int FECHADO_GRAUS = 0;
static const int ABERTO_GRAUS = 180; // AJUSTE: 45, 90, 120 etc. conforme a tampa; sem bater nos limites
static const unsigned long RECONNECT_INTERVAL_MS = 5000UL;
static const unsigned long WIFI_RECONNECT_MS = 10000UL;

// ISRG Root X1: CA divulgada na documentação HiveMQ Cloud para MQTT/TLS.
static const char MQTT_ROOT_CA[] PROGMEM = R"CERT(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
)CERT";

BearSSL::WiFiClientSecure tlsClient;
BearSSL::X509List trustAnchor(MQTT_ROOT_CA);
PubSubClient mqtt(tlsClient);
Servo servoTampa;

bool servoAtivado = false;
String ultimoCommandId = "";
String estadoTampa = "unknown"; // Posicao desconhecida apos o boot: NAO mover automaticamente.
bool ntpIniciado = false;
unsigned long ultimaTentativaWifi = 0;
unsigned long ultimaTentativaMqtt = 0;
unsigned long ultimoHeartbeat = 0;
unsigned long ultimoLogNtp = 0;
int ultimoWifiStatus = -999;
bool mqttEstavaConectado = false;

static const unsigned long HEARTBEAT_MS = 10000UL;
static const unsigned long WIFI_RETRY_MS = 12000UL;
static const unsigned long MQTT_RETRY_MS = 6000UL;
static const unsigned long NTP_LOG_MS = 10000UL;

void logInicio(const char* componente) {
  Serial.printf("[%10lu ms] [%-6s] ", millis(), componente);
}

const char* nomeEstadoWifi(int status) {
  switch (status) {
    case WL_IDLE_STATUS: return "IDLE";
    case WL_NO_SSID_AVAIL: return "REDE NAO ENCONTRADA";
    case WL_SCAN_COMPLETED: return "BUSCA CONCLUIDA";
    case WL_CONNECTED: return "CONECTADO";
    case WL_CONNECT_FAILED: return "FALHA DE CONEXAO";
    case WL_CONNECTION_LOST: return "CONEXAO PERDIDA";
    case WL_DISCONNECTED: return "DESCONECTADO";
    default: return "DESCONHECIDO";
  }
}

const char* descricaoEstadoMqtt(int estado) {
  switch (estado) {
    case -4: return "tempo de resposta excedido";
    case -3: return "conexao perdida";
    case -2: return "conexao TCP/TLS falhou";
    case -1: return "desconectado";
    case  0: return "conectado";
    case  1: return "protocolo MQTT recusado";
    case  2: return "clientId rejeitado";
    case  3: return "broker indisponivel";
    case  4: return "usuario ou senha rejeitados";
    case  5: return "acesso nao autorizado";
    default: return "erro MQTT desconhecido";
  }
}

bool horarioSincronizado() {
  return time(nullptr) > 1700000000;
}

void logEstadoWifiSeMudar() {
  const int atual = (int)WiFi.status();
  if (atual == ultimoWifiStatus) return;
  ultimoWifiStatus = atual;
  logInicio("WIFI");
  Serial.printf("Estado: %s (codigo %d)\n", nomeEstadoWifi(atual), atual);
  if (atual == WL_CONNECTED) {
    logInicio("WIFI");
    Serial.printf("IP=%s | Gateway=%s | DNS=%s | RSSI=%d dBm\n",
      WiFi.localIP().toString().c_str(),
      WiFi.gatewayIP().toString().c_str(),
      WiFi.dnsIP().toString().c_str(),
      WiFi.RSSI());
    ntpIniciado = false;
    ultimaTentativaMqtt = 0; // Pode tentar assim que NTP responder.
  } else {
    ntpIniciado = false;
  }
}

void conectarWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  const unsigned long agora = millis();
  if (ultimaTentativaWifi != 0 && agora - ultimaTentativaWifi < WIFI_RETRY_MS) return;
  ultimaTentativaWifi = agora;
  logInicio("WIFI");
  Serial.printf("Tentando associar a rede '%s' (senha omitida no log) ...\n", WIFI_SSID);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

void iniciarNtpSeNecessario() {
  if (ntpIniciado || WiFi.status() != WL_CONNECTED) return;
  ntpIniciado = true;
  logInicio("NTP");
  Serial.println(F("Sincronizando relogio via pool.ntp.org e time.google.com (UTC) ..."));
  configTime(0, 0, "pool.ntp.org", "time.google.com");
}

void logAguardandoNtp() {
  const unsigned long agora = millis();
  if (ultimoLogNtp == 0 || agora - ultimoLogNtp >= NTP_LOG_MS) {
    ultimoLogNtp = agora;
    logInicio("NTP");
    Serial.printf("Ainda sem hora valida (epoch=%lu); TLS nao inicia sem horario.\n",
                  (unsigned long)time(nullptr));
  }
}

void publicarAck(const char* commandId, const char* action,
                 const char* status, const char* detail) {
  if (!mqtt.connected()) {
    logInicio("ACK");
    Serial.println(F("Nao enviado: MQTT desconectado."));
    return;
  }
  StaticJsonDocument<384> ack;
  ack["type"] = "ack";
  ack["deviceId"] = DEVICE_ID;
  ack["commandId"] = commandId;
  ack["action"] = action;
  ack["status"] = status;
  ack["detail"] = detail;
  char buffer[384];
  const size_t n = serializeJson(ack, buffer, sizeof(buffer));
  if (n == 0 || n >= sizeof(buffer)) {
    logInicio("ACK");
    Serial.println(F("ERRO: ACK maior que o buffer; nao enviado."));
    return;
  }
  logInicio("ACK");
  Serial.print(F("TX topico='"));
  Serial.print(MQTT_TOPIC);
  Serial.print(F("' payload="));
  Serial.println(buffer);
  const bool enviado = mqtt.publish(MQTT_TOPIC, buffer, false); // Retain=false.
  logInicio("ACK");
  Serial.println(enviado ? F("Publicado com sucesso.") : F("FALHA na publicacao."));
}

// Exibe toda mensagem recebida em formato legivel e impede caracteres de controle
// de baguncarem o Monitor Serial.
void imprimirPayload(const byte* payload, unsigned int length) {
  logInicio("MQTT");
  Serial.print(F("RX JSON bruto: "));
  const unsigned int maxPrint = (length > 600U) ? 600U : length;
  for (unsigned int i = 0; i < maxPrint; ++i) {
    const unsigned char c = payload[i];
    if (c == '\n') Serial.print(F("\\n"));
    else if (c == '\r') Serial.print(F("\\r"));
    else if (c == '\t') Serial.print(F("\\t"));
    else if (c >= 32 && c <= 126) Serial.write(c);
    else Serial.print('?');
  }
  if (length > maxPrint) Serial.print(F(" ... [truncado]"));
  Serial.println();
}

void aoReceberMqtt(char* topic, byte* payload, unsigned int length) {
  logInicio("MQTT");
  Serial.printf("MENSAGEM RECEBIDA! Topico='%s' | %u bytes\n", topic, length);
  imprimirPayload(payload, length);
  if (strcmp(topic, MQTT_TOPIC) != 0) {
    logInicio("MQTT");
    Serial.println(F("IGNORADA: topico diferente do esperado."));
    return;
  }
  if (length == 0 || length > 600) {
    logInicio("MQTT");
    Serial.println(F("IGNORADA: payload vazio ou maior que 600 bytes."));
    return;
  }

  StaticJsonDocument<768> cmd;
  const DeserializationError erro = deserializeJson(cmd, (const char*)payload, length);
  if (erro) {
    logInicio("JSON");
    Serial.print(F("ERRO de parse: "));
    Serial.println(erro.c_str());
    return;
  }
  const char* tipo = cmd["type"] | "";
  const char* destinatario = cmd["deviceId"] | "";
  const char* id = cmd["commandId"] | "";
  const char* acao = cmd["action"] | "";
  logInicio("JSON");
  Serial.printf("type='%s' | deviceId='%s' | commandId='%s' | action='%s'\n",
                tipo, destinatario, id, acao);

  // O Flutter recebe ACKs no mesmo topico. Nao executar ACK como comando.
  if (strcmp(tipo, "command") != 0) {
    logInicio("JSON");
    Serial.println(F("IGNORADO: nao e mensagem do tipo command (pode ser nosso ACK)."));
    return;
  }
  if (strcmp(destinatario, DEVICE_ID) != 0) {
    logInicio("JSON");
    Serial.printf("IGNORADO: destinatario '%s' nao e '%s'.\n", destinatario, DEVICE_ID);
    return;
  }
  if (id[0] == '\0' || strlen(id) > 72) {
    logInicio("JSON");
    Serial.println(F("IGNORADO: commandId ausente ou acima de 72 caracteres."));
    return;
  }
  if (strcmp(acao, "open") != 0 && strcmp(acao, "close") != 0) {
    logInicio("JSON");
    Serial.printf("IGNORADO: acao '%s' nao permitida.\n", acao);
    publicarAck(id, acao, "ignored", "acao desconhecida");
    return;
  }
  if (ultimoCommandId == id) {
    logInicio("SERVO");
    Serial.printf("Comando repetido ('%s'); servo nao sera movido.\n", id);
    publicarAck(id, acao, "ok", "comando ja recebido");
    return;
  }
  ultimoCommandId = id;

  const bool abrir = (strcmp(acao, "open") == 0);
  const char* destino = abrir ? "open" : "closed";
  const int angulo = abrir ? ABERTO_GRAUS : FECHADO_GRAUS;
  if (estadoTampa == destino) {
    logInicio("SERVO");
    Serial.printf("Tampa ja esta em '%s'; nao mover.\n", destino);
    publicarAck(id, acao, "ok", "tampa ja esta na posicao solicitada");
    return;
  }

  // Nunca movimentar no boot ou por reconexao: somente por JSON valido.
  // IMPORTANTE: Servo.attach(pin) sozinho usa 1500 us (aprox. 90 graus).
  // A sobrecarga de 4 argumentos, disponivel no ESP8266 core 3.1.1,
  // ja ativa o servo com o proprio angulo solicitado pelo comando.
  // Isso evita gerar primeiro um pulso de 90 graus sem que o app tenha pedido 90.
  if (!servoAtivado) {
    logInicio("SERVO");
    Serial.printf("Primeiro comando: attach D5 (GPIO14) com alvo inicial=%d graus.\n", angulo);
    const uint8_t pinoRetornado = servoTampa.attach(SERVO_PIN, 1000, 2000, angulo);
    servoAtivado = servoTampa.attached();
    logInicio("SERVO");
    Serial.printf("Resultado attach: attached=%s | retorno=%u | GPIO=%u\n",
                  servoAtivado ? "SIM" : "NAO", pinoRetornado, (unsigned int)SERVO_PIN);
    if (!servoAtivado) {
      logInicio("SERVO");
      Serial.println(F("FALHA: biblioteca nao vinculou servo ao pino; comando nao aplicado."));
      publicarAck(id, acao, "error", "falha ao associar servo ao GPIO");
      return;
    }
  }
  logInicio("SERVO");
  Serial.printf("COMANDO '%s': estado anterior=%s | destino=%s | angulo=%d graus\n",
                acao, estadoTampa.c_str(), destino, angulo);
  servoTampa.write(angulo);
  logInicio("SERVO");
  Serial.printf("PWM configurado: D5/GPIO14 | %d graus | pulso=%d us | attached=%s\n",
                servoTampa.read(), servoTampa.readMicroseconds(),
                servoTampa.attached() ? "SIM" : "NAO");
  logInicio("SERVO");
  Serial.println(F("ATENCAO: PWM configurado nao comprova tensao no servo nem movimento fisico."));
  estadoTampa = destino;
  publicarAck(id, acao, "ok", "comando PWM emitido; sem leitura da posicao fisica");
}

void conectarMqtt() {
  if (mqtt.connected() || WiFi.status() != WL_CONNECTED) return;
  iniciarNtpSeNecessario();
  if (!horarioSincronizado()) {
    logAguardandoNtp();
    return;
  }
  const unsigned long agora = millis();
  if (ultimaTentativaMqtt != 0 && agora - ultimaTentativaMqtt < MQTT_RETRY_MS) return;
  ultimaTentativaMqtt = agora;

  const time_t agoraUtc = time(nullptr);
  const struct tm *horario = gmtime(&agoraUtc);
  char horaTexto[32] = "indisponivel";
  if (horario != nullptr) {
    strftime(horaTexto, sizeof(horaTexto), "%Y-%m-%d %H:%M:%S UTC", horario);
  }
  logInicio("NTP");
  Serial.printf("Relogio valido: %s\n", horaTexto);

  logInicio("DNS");
  Serial.printf("Resolvendo '%s' ...\n", MQTT_HOST);
  IPAddress ipBroker;
  if (!WiFi.hostByName(MQTT_HOST, ipBroker)) {
    logInicio("DNS");
    Serial.println(F("FALHA: nao foi possivel resolver o hostname do HiveMQ."));
    return;
  }
  logInicio("DNS");
  Serial.printf("Broker resolvido: %s\n", ipBroker.toString().c_str());

  const String clientId = "LIXEIRA-ESP8266-" + String(ESP.getChipId(), HEX);
  logInicio("TLS");
  Serial.printf("Conectando %s:%u com validacao CA (sem setInsecure) ...\n",
                MQTT_HOST, MQTT_PORT);
  logInicio("MQTT");
  Serial.printf("Enviando CONNECT clientId='%s' user='%s' (senha omitida) ...\n",
                clientId.c_str(), MQTT_USERNAME);

  // A chamada inclui abertura TCP, negociacao TLS e autenticacao MQTT.
  const bool conectado = mqtt.connect(clientId.c_str(), MQTT_USERNAME, MQTT_PASSWORD);
  if (conectado) {
    logInicio("MQTT");
    Serial.println(F("CONECTADO E AUTENTICADO no HiveMQ Cloud via TLS!"));
    const bool inscrito = mqtt.subscribe(MQTT_TOPIC, 1);
    logInicio("MQTT");
    Serial.printf("SUBSCRIBE '%s' (QoS=1): %s\n", MQTT_TOPIC,
                  inscrito ? "OK" : "FALHOU");
    if (inscrito) {
      logInicio("SERVO");
      Serial.printf("Aguardando comandos. Estado atual='%s'. Nenhum movimento automatico.\n",
                    estadoTampa.c_str());
    }
  } else {
    const int estado = mqtt.state();
    logInicio("MQTT");
    Serial.printf("FALHA: state=%d (%s).\n", estado, descricaoEstadoMqtt(estado));
    char descricaoTls[180] = {0};
    const int erroTls = tlsClient.getLastSSLError(descricaoTls, sizeof(descricaoTls));
    if (erroTls != 0) {
      logInicio("TLS");
      Serial.printf("Erro TLS %d: %s\n", erroTls, descricaoTls);
    } else {
      logInicio("TLS");
      Serial.println(F("Sem erro TLS detalhado; conferir broker, credenciais e rede."));
    }
  }
}

void heartbeat() {
  const unsigned long agora = millis();
  if (ultimoHeartbeat != 0 && agora - ultimoHeartbeat < HEARTBEAT_MS) return;
  ultimoHeartbeat = agora;
  logInicio("STATUS");
  Serial.printf("VIVO | WiFi=%s | MQTT=%s (state=%d) | RSSI=%d dBm | heap=%u B | tampa=%s\n",
                nomeEstadoWifi((int)WiFi.status()),
                mqtt.connected() ? "ON" : "OFF", mqtt.state(),
                WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : 0,
                ESP.getFreeHeap(), estadoTampa.c_str());
}

void setup() {
  Serial.begin(115200);
  delay(350);
  Serial.println();
  Serial.println(F("============================================================"));
  Serial.println(F(" LIXEIRA INTELIGENTE - NodeMCU ESP8266 - LOG COMPLETO"));
  Serial.println(F(" MONITOR SERIAL: 115200 baud | Upload Speed independe disso"));
  Serial.println(F("============================================================"));
  logInicio("BOOT");
  Serial.printf("Reset: %s | ESP ChipId=%06X | SDK=%s\n",
                ESP.getResetReason().c_str(), ESP.getChipId(), ESP.getSdkVersion());
  logInicio("CONFIG");
  Serial.printf("WiFi SSID='%s' | MQTT=%s:%u | topico='%s' | deviceId='%s'\n",
                WIFI_SSID, MQTT_HOST, MQTT_PORT, MQTT_TOPIC, DEVICE_ID);
  logInicio("CONFIG");
  Serial.printf("Servo=D5(GPIO14) | fechar=%d graus | abrir=%d graus\n",
                FECHADO_GRAUS, ABERTO_GRAUS);
  logInicio("SEGUR");
  Serial.println(F("TLS com CA valida; senhas NAO sao mostradas no log."));
  logInicio("SERVO");
  Serial.println(F("Nenhum movimento no boot. Servo so sera ativado apos JSON valido."));
  logInicio("SERVO");
  Serial.println(F("Confira: sinal=D5(GPIO14), negativo=GND comum, positivo=5V EXTERNO do servo (nao VIN sem teste)."));

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  tlsClient.setTrustAnchors(&trustAnchor);
  mqtt.setServer(MQTT_HOST, MQTT_PORT);
  mqtt.setCallback(aoReceberMqtt);
  if (!mqtt.setBufferSize(768)) {
    logInicio("MQTT");
    Serial.println(F("AVISO: sem memoria para buffer MQTT 768 bytes."));
  } else {
    logInicio("MQTT");
    Serial.println(F("Buffer MQTT de 768 bytes configurado."));
  }
  mqtt.setKeepAlive(30);
  mqtt.setSocketTimeout(12);
  logInicio("BOOT");
  Serial.println(F("Inicializacao concluida. Iniciando Wi-Fi ..."));
  conectarWifi();
  Serial.flush();
}

void loop() {
  const bool wifiOk = WiFi.status() == WL_CONNECTED;
  logEstadoWifiSeMudar();
  if (!wifiOk) {
    if (mqttEstavaConectado) {
      logInicio("MQTT");
      Serial.println(F("Conexao interrompida devido a perda do Wi-Fi."));
      mqttEstavaConectado = false;
    }
    ntpIniciado = false;
    conectarWifi();
  } else {
    if (mqtt.connected()) {
      const bool ok = mqtt.loop();
      if (!ok) {
        logInicio("MQTT");
        Serial.printf("mqtt.loop() retornou false; state=%d (%s)\n",
                      mqtt.state(), descricaoEstadoMqtt(mqtt.state()));
      }
    } else {
      if (mqttEstavaConectado) {
        logInicio("MQTT");
        Serial.printf("Desconectou do HiveMQ: state=%d (%s).\n",
                      mqtt.state(), descricaoEstadoMqtt(mqtt.state()));
        mqttEstavaConectado = false;
      }
      conectarMqtt();
    }
    if (mqtt.connected()) mqttEstavaConectado = true;
  }
  heartbeat(); // Log a cada 10 segundos MESMO sem Wi-Fi ou MQTT.
  delay(20);
}
