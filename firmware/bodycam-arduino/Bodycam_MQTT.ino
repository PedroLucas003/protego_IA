#include "esp_camera.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include "board_config.h"

const char *ssid     = "PEDRO_JDN";
const char *password = "03072003";

const char* mqtt_broker    = "kodama.proxy.rlwy.net";
const int   mqtt_port      = 38909;
const char* mqtt_client_id = "esp32_cam_01";

const char* TOPIC_STATUS   = "policia/cam01/status";
const char* TOPIC_COMANDOS = "policia/cam01/comandos";

const char* CA_CERT = R"(
-----BEGIN CERTIFICATE-----
MIIDGTCCAgGgAwIBAgIUCfgs4VnCS2KQp9smfWc4ecYRo3QwDQYJKoZIhvcNAQEL
BQAwHDEaMBgGA1UEAwwRUHJvdGVnb0lBLVJvb3QtQ0EwHhcNMjYwNTIxMTczMzQ1
WhcNMzYwNTE4MTczMzQ1WjAcMRowGAYDVQQDDBFQcm90ZWdvSUEtUm9vdC1DQTCC
ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAN+utFNspIlO/1vpZYRAS4vO
gtkg8+108XbWWRuTZ5EnnufvDGtAhYDgrXx5RQ4FMg3vuD3mVwGHzAg0HjaPgcM1
/1O8CGvzd4zYFF2501IqvJqdQj5pNSiKANCgpTQjTekvXPIjMUoyUCTdzp40PxRI
dAjCBKuB10P0Cc1p7sJ3k/QUtECEiSKEkrs3vJDgSLCCj//nXWB+UQcTZGlYkWKM
TXhPTMd4fI3IH9YGoqgCOi2KlbXtFA9gIsqcsmeOZINirKrBWzL82ePvn9u6Mszl
yhBggI1Ac1TlWHuwtYmzejWsIyZc1qq9ukABN8h9sBiY7+Yyh288IKYnwJyx1DUC
AwEAAaNTMFEwHQYDVR0OBBYEFG0bnlVrtl6MCU8xfjwS21i65OdcMB8GA1UdIwQY
MBaAFG0bnlVrtl6MCU8xfjwS21i65OdcMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZI
hvcNAQELBQADggEBAAGAe7IxZGnaDz/jB81ODcKs1stNcX1b+yCSBnHeLaM5lzl+
Xcd/McNuJC1zHm/MzPILzqhDxQg/CpjGYuFND4bR3KnTFqInGR/bu+MP0BZv6Jkn
jVIa8BQxhlk+vCVn2okmJ7nuDymwrrGYRAE9xs4BJ4MTA8sjGo9wYv0wkqX0O3LI
ea7F66ZCyV3/9CsFSqETy7QEY7ggLYW7jMSP75hccT8kDS73sD9Oc3PapMF7RUh6
lsZP4C43CmoZqerME7M3E3wckfMn1kp0JoD2xbNiKvp6YByp5mFRBTQAduS9wTp6
Y1LxKjJ72FNYPcAhkIj646Zs7Y04HO0qRpBI1S0=
-----END CERTIFICATE-----
)";

const char* CLIENT_CERT = R"(
-----BEGIN CERTIFICATE-----
MIIDAjCCAeqgAwIBAgIUIuXxB687hcBTS5v/NxMlZu2x6kwwDQYJKoZIhvcNAQEL
BQAwHDEaMBgGA1UEAwwRUHJvdGVnb0lBLVJvb3QtQ0EwHhcNMjYwNTIxMTc1MzIy
WhcNMzYwNTE4MTc1MzIyWjAWMRQwEgYDVQQDDAtlc3AzMmNhbS0wMTCCASIwDQYJ
KoZIhvcNAQEBBQADggEPADCCAQoCggEBALTJ3CMg0Csj27e5wDbS/LMI+WPK4B+u
UJ9nGOlTcv8fu09SiE6ye3Aqf66PHlZhIhJGAYfH2iNdiSDVtpHTrqQgiJcAS0X0
RvJPx5pDA5yFCYgEdqOMxZe40zSxXtyxZj/vWlk0EaZOvZIGWZnR69Yvejr4j9vM
e1Of2hOXOtbMhT3UNGXM8uQmzq2GL2WM94fQYGg9D5SnDIMukMixqV4ttlqruCgt
zrqEkXFUIE46jfeBdu+ASJcxsxOmw3C+is5CfpvsLuOHtzZZqHAvRhLGonSGaCRo
JTb+dXOKs+K98e5qfFDZyJ/RdD/8utSF6p3ZmRY9M4cJIpImKIvY9/UCAwEAAaNC
MEAwHQYDVR0OBBYEFN4KKGyAyoUU41o1d9jtmKzO+QBtMB8GA1UdIwQYMBaAFG0b
nlVrtl6MCU8xfjwS21i65OdcMA0GCSqGSIb3DQEBCwUAA4IBAQCYkvFsGnMdCOWc
UaTUgQtHnNwasjRb7zTw2xFnKM8k3Uge+l2LZPfH5ifsFIvUqH8vxKGHESPfnS22
dBZvTDHcOgJ6Q97gMuU2h+z3XDLHHzT/LOnSaMp/VEx6WWGzwdSUjI78o0PgrLFR
5haksgv75wTVlOhejZNmihwmErAmb+OqiNNDtSFPXyLhipzvIHH4FQXSiTbNAbl8
gZjRbrkE5Tp4pjniHY6HF7gM04Y0ETkQj/VN5i16422xWluhtBMSVwV3jZjFRNDd
lcDFBPn29bgZuThQjx4vlAJveubn9AYRWXoPV3ZkHUaXLR9qDzWwZ/FEbb29Jydb
gxEZFUuH
-----END CERTIFICATE-----
)";

const char* CLIENT_KEY = R"(
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC0ydwjINArI9u3
ucA20vyzCPljyuAfrlCfZxjpU3L/H7tPUohOsntwKn+ujx5WYSISRgGHx9ojXYkg
1baR066kIIiXAEtF9EbyT8eaQwOchQmIBHajjMWXuNM0sV7csWY/71pZNBGmTr2S
BlmZ0evWL3o6+I/bzHtTn9oTlzrWzIU91DRlzPLkJs6thi9ljPeH0GBoPQ+UpwyD
LpDIsaleLbZaq7goLc66hJFxVCBOOo33gXbvgEiXMbMTpsNwvorOQn6b7C7jh7c2
WahwL0YSxqJ0hmgkaCU2/nVzirPivfHuanxQ2cif0XQ//LrUheqd2ZkWPTOHCSKS
JiiL2Pf1AgMBAAECggEAArXWAYbP6B2pARedTJUcKbj0OC1F7+OmnMUoZ/MS0cVR
gw5rMbbWR+ezM1Q88bGSF7EJ+9WgrRANarsZehUw1JASTCU6e6l+WMqeZO8lQjby
XiIm/yuwmKYyMGOKVwenz0SQ166Cpzod+G707+voO7VJgVHRoktt++J1G/8T6D1x
Oht0Q3VLrD8MLdHbxgoyounLO+qoNqcM2OPxK6V+sSJ7Z8Vk2+h6DYDAdkUG2Bwk
Oj2NUcnyP4FJRE9IO6Hm3yvE8PuJ+cxmOWwRtHB/jwxQf9i0sBJwwLGhHosEVPhy
328xsYKVG/tpUBdoSkmRdFa7jbHcOxQwaa58zLK5nwKBgQDjUsPHE1C7dSXVFtxp
0lq08EybkjgQAIwnvEu3L1qkBKWfqvNMGpcCOZAaRwizvdwuR2P1GCk8+HHC1iz/
0mAdZbd3ocsYwv1TI0JehViWTxIFXkd/5p2RXJeO2UeMtHVpsRCQ6LZNi4SXlAdm
zPHHEuxpGqxBmzYWswx9AT9+bwKBgQDLmEoLX+N+jjardIUjiIVVMWS5UQg4sNQF
fh1Ubgs9d3NdGhTBstOmVkYo/d9DGW1Enthxd6U0Jly5f2Ju1COriGzF5tpa9Q9F
PqiEioJEAstFGySU640hkAr4y/5l2USIyo6mTiQZ36lqBlCvb3LavY6Ag7ss0tTf
WXWFtjyh2wKBgQCYfqEPHwn9duzWMevSoWZwEvOROVmagoOC9HHmhUHM3cEth0SH
PR8oQu1Ec3qG+UqHUSTg+kBPwmquRXcSdlI75kxZWJQiHExMRU70kYeH7astJr3Y
MyBorzCMh33UCgrpx/pQ+4uwIXPlK0x7zegzn6IwL9B2gmSafapXAUtSyQKBgQCB
Sfprcr8zFPietOX/hKi3SyCdllnUNmbN/iJ+BUvaAssd6nwX7Yn+bXcsfNuU7sa2
9vCYTdR5Y4squTw3CTyFp6L7ofg0Hr9Nx9aYJKVIr0WKYww+Db+X+rMc/95Tqz+c
ZpVkAudmDuS00cHXRrz3L70Y2463jkNkepjpCqtCVQKBgCb4fFab5Qf4j7eZGpr5
PhtyAUuppBQHZ74snfiP3Xgpj0xLL1K9LrGCGAWfwAj6ADON6y/MwnNvFJD/+Agj
F3hJy3PnVHiisS0nX4UbkYI19509pc5iFPj4bfhWIMXvRdx+vIyeknvgK6Dyifco
CjsKZESRAfRYkXBIQvaiGqjm
-----END PRIVATE KEY-----
)";

WiFiClientSecure secureClient;
PubSubClient     mqttClient(secureClient);

void startCameraServer();
void setupLedFlash();

void callback(char* topic, byte* payload, unsigned int length) {
  String msg = "";
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.printf("📥 [%s]: %s\n", topic, msg.c_str());
  if (msg == "LIGAR_FLASH") {
    digitalWrite(4, HIGH);
    mqttClient.publish("policia/cam01/respostas", "{\"status_flash\": \"LIGADO\"}");
  } else if (msg == "DESLIGAR_FLASH") {
    digitalWrite(4, LOW);
    mqttClient.publish("policia/cam01/respostas", "{\"status_flash\": \"DESLIGADO\"}");
  }
}

void reconnectMQTT() {
  int tentativas = 0;
  while (!mqttClient.connected() && tentativas < 5) {
    Serial.printf("🔄 Conectando MQTT em %s:%d (mTLS)...\n", mqtt_broker, mqtt_port);
    if (mqttClient.connect(mqtt_client_id, "esp32_cam_01", "")) {
      Serial.println("✅ MQTT conectado com mTLS!");
      mqttClient.publish(TOPIC_STATUS, "{\"status\": \"ONLINE\", \"tls\": \"mTLS\"}");
      mqttClient.subscribe(TOPIC_COMANDOS);
    } else {
      Serial.printf("❌ Falhou (estado=%d). Tentando em 5s...\n", mqttClient.state());
      delay(5000);
      tentativas++;
    }
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(4, OUTPUT);
  digitalWrite(4, LOW);

  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.frame_size   = FRAMESIZE_UXGA;
  config.pixel_format = PIXFORMAT_JPEG;
  config.grab_mode    = CAMERA_GRAB_WHEN_EMPTY;
  config.fb_location  = CAMERA_FB_IN_PSRAM;
  config.jpeg_quality = 12;
  config.fb_count     = 1;

  if (psramFound()) {
    config.jpeg_quality = 10;
    config.fb_count     = 2;
    config.grab_mode    = CAMERA_GRAB_LATEST;
  } else {
    config.frame_size  = FRAMESIZE_SVGA;
    config.fb_location = CAMERA_FB_IN_DRAM;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("❌ Camera init failed: 0x%x\n", err);
    return;
  }

  sensor_t *s = esp_camera_sensor_get();
  if (s->id.PID == OV3660_PID) {
    s->set_vflip(s, 1);
    s->set_brightness(s, 1);
    s->set_saturation(s, -2);
  }
  s->set_framesize(s, FRAMESIZE_VGA);

#if defined(LED_GPIO_NUM)
  setupLedFlash();
#endif

  WiFi.begin(ssid, password);
  WiFi.setSleep(false);
  Serial.print("📶 Conectando WiFi");
  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }
  Serial.printf("\n✅ WiFi: %s\n", WiFi.localIP().toString().c_str());

  startCameraServer();
  Serial.printf("📷 Camera: http://%s\n", WiFi.localIP().toString().c_str());

  secureClient.setCACert(CA_CERT);
  secureClient.setCertificate(CLIENT_CERT);
  secureClient.setPrivateKey(CLIENT_KEY);

  mqttClient.setServer(mqtt_broker, mqtt_port);
  mqttClient.setCallback(callback);
  mqttClient.setBufferSize(512);

  reconnectMQTT();
}

void loop() {
  if (!mqttClient.connected()) reconnectMQTT();
  mqttClient.loop();
  delay(10);
}
