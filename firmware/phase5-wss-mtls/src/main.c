/*
 * ============================================================
 *  Phase 5 — MQTT over WebSocket Secure (WSS + mTLS)
 *  ESP-IDF + PlatformIO
 *  Broker: kodama.proxy.rlwy.net:8084/mqtt
 * ============================================================
 */

#include <stdio.h>
#include <string.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/event_groups.h"
#include "esp_system.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "nvs_flash.h"
#include "mqtt_client.h"

static const char* TAG = "PHASE5";

#define WIFI_SSID     "PEDRO_JDN"
#define WIFI_PASSWORD "03072003"
#define WIFI_CONNECTED_BIT BIT0

static EventGroupHandle_t wifi_event_group;

// WSS — WebSocket Secure com mTLS
#define MQTT_BROKER_URI "wss://kodama.proxy.rlwy.net:8084/mqtt"
#define MQTT_CLIENT_ID  "esp32-phase5-wss"
#define TOPIC_STATUS    "policia/cam01/status"

static const char* CA_CERT =
"-----BEGIN CERTIFICATE-----\n"
"MIIDGTCCAgGgAwIBAgIUCfgs4VnCS2KQp9smfWc4ecYRo3QwDQYJKoZIhvcNAQEL\n"
"BQAwHDEaMBgGA1UEAwwRUHJvdGVnb0lBLVJvb3QtQ0EwHhcNMjYwNTIxMTczMzQ1\n"
"WhcNMzYwNTE4MTczMzQ1WjAcMRowGAYDVQQDDBFQcm90ZWdvSUEtUm9vdC1DQTCC\n"
"ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAN+utFNspIlO/1vpZYRAS4vO\n"
"gtkg8+108XbWWRuTZ5EnnufvDGtAhYDgrXx5RQ4FMg3vuD3mVwGHzAg0HjaPgcM1\n"
"/1O8CGvzd4zYFF2501IqvJqdQj5pNSiKANCgpTQjTekvXPIjMUoyUCTdzp40PxRI\n"
"dAjCBKuB10P0Cc1p7sJ3k/QUtECEiSKEkrs3vJDgSLCCj//nXWB+UQcTZGlYkWKM\n"
"TXhPTMd4fI3IH9YGoqgCOi2KlbXtFA9gIsqcsmeOZINirKrBWzL82ePvn9u6Mszl\n"
"yhBggI1Ac1TlWHuwtYmzejWsIyZc1qq9ukABN8h9sBiY7+Yyh288IKYnwJyx1DUC\n"
"AwEAAaNTMFEwHQYDVR0OBBYEFG0bnlVrtl6MCU8xfjwS21i65OdcMB8GA1UdIwQY\n"
"MBaAFG0bnlVrtl6MCU8xfjwS21i65OdcMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZI\n"
"hvcNAQELBQADggEBAAGAe7IxZGnaDz/jB81ODcKs1stNcX1b+yCSBnHeLaM5lzl+\n"
"Xcd/McNuJC1zHm/MzPILzqhDxQg/CpjGYuFND4bR3KnTFqInGR/bu+MP0BZv6Jkn\n"
"jVIa8BQxhlk+vCVn2okmJ7nuDymwrrGYRAE9xs4BJ4MTA8sjGo9wYv0wkqX0O3LI\n"
"ea7F66ZCyV3/9CsFSqETy7QEY7ggLYW7jMSP75hccT8kDS73sD9Oc3PapMF7RUh6\n"
"lsZP4C43CmoZqerME7M3E3wckfMn1kp0JoD2xbNiKvp6YByp5mFRBTQAduS9wTp6\n"
"Y1LxKjJ72FNYPcAhkIj646Zs7Y04HO0qRpBI1S0=\n"
"-----END CERTIFICATE-----\n";

static const char* CLIENT_CERT =
"-----BEGIN CERTIFICATE-----\n"
"MIIDAjCCAeqgAwIBAgIUIuXxB687hcBTS5v/NxMlZu2x6kwwDQYJKoZIhvcNAQEL\n"
"BQAwHDEaMBgGA1UEAwwRUHJvdGVnb0lBLVJvb3QtQ0EwHhcNMjYwNTIxMTc1MzIy\n"
"WhcNMzYwNTE4MTc1MzIyWjAWMRQwEgYDVQQDDAtlc3AzMmNhbS0wMTCCASIwDQYJ\n"
"KoZIhvcNAQEBBQADggEPADCCAQoCggEBALTJ3CMg0Csj27e5wDbS/LMI+WPK4B+u\n"
"UJ9nGOlTcv8fu09SiE6ye3Aqf66PHlZhIhJGAYfH2iNdiSDVtpHTrqQgiJcAS0X0\n"
"RvJPx5pDA5yFCYgEdqOMxZe40zSxXtyxZj/vWlk0EaZOvZIGWZnR69Yvejr4j9vM\n"
"e1Of2hOXOtbMhT3UNGXM8uQmzq2GL2WM94fQYGg9D5SnDIMukMixqV4ttlqruCgt\n"
"zrqEkXFUIE46jfeBdu+ASJcxsxOmw3C+is5CfpvsLuOHtzZZqHAvRhLGonSGaCRo\n"
"JTb+dXOKs+K98e5qfFDZyJ/RdD/8utSF6p3ZmRY9M4cJIpImKIvY9/UCAwEAAaNC\n"
"MEAwHQYDVR0OBBYEFN4KKGyAyoUU41o1d9jtmKzO+QBtMB8GA1UdIwQYMBaAFG0b\n"
"nlVrtl6MCU8xfjwS21i65OdcMA0GCSqGSIb3DQEBCwUAA4IBAQCYkvFsGnMdCOWc\n"
"UaTUgQtHnNwasjRb7zTw2xFnKM8k3Uge+l2LZPfH5ifsFIvUqH8vxKGHESPfnS22\n"
"dBZvTDHcOgJ6Q97gMuU2h+z3XDLHHzT/LOnSaMp/VEx6WWGzwdSUjI78o0PgrLFR\n"
"5haksgv75wTVlOhejZNmihwmErAmb+OqiNNDtSFPXyLhipzvIHH4FQXSiTbNAbl8\n"
"gZjRbrkE5Tp4pjniHY6HF7gM04Y0ETkQj/VN5i16422xWluhtBMSVwV3jZjFRNDd\n"
"lcDFBPn29bgZuThQjx4vlAJveubn9AYRWXoPV3ZkHUaXLR9qDzWwZ/FEbb29Jydb\n"
"gxEZFUuH\n"
"-----END CERTIFICATE-----\n";

static const char* CLIENT_KEY =
"-----BEGIN PRIVATE KEY-----\n"
"MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC0ydwjINArI9u3\n"
"ucA20vyzCPljyuAfrlCfZxjpU3L/H7tPUohOsntwKn+ujx5WYSISRgGHx9ojXYkg\n"
"1baR066kIIiXAEtF9EbyT8eaQwOchQmIBHajjMWXuNM0sV7csWY/71pZNBGmTr2S\n"
"BlmZ0evWL3o6+I/bzHtTn9oTlzrWzIU91DRlzPLkJs6thi9ljPeH0GBoPQ+UpwyD\n"
"LpDIsaleLbZaq7goLc66hJFxVCBOOo33gXbvgEiXMbMTpsNwvorOQn6b7C7jh7c2\n"
"WahwL0YSxqJ0hmgkaCU2/nVzirPivfHuanxQ2cif0XQ//LrUheqd2ZkWPTOHCSKS\n"
"JiiL2Pf1AgMBAAECggEAArXWAYbP6B2pARedTJUcKbj0OC1F7+OmnMUoZ/MS0cVR\n"
"gw5rMbbWR+ezM1Q88bGSF7EJ+9WgrRANarsZehUw1JASTCU6e6l+WMqeZO8lQjby\n"
"XiIm/yuwmKYyMGOKVwenz0SQ166Cpzod+G707+voO7VJgVHRoktt++J1G/8T6D1x\n"
"Oht0Q3VLrD8MLdHbxgoyounLO+qoNqcM2OPxK6V+sSJ7Z8Vk2+h6DYDAdkUG2Bwk\n"
"Oj2NUcnyP4FJRE9IO6Hm3yvE8PuJ+cxmOWwRtHB/jwxQf9i0sBJwwLGhHosEVPhy\n"
"328xsYKVG/tpUBdoSkmRdFa7jbHcOxQwaa58zLK5nwKBgQDjUsPHE1C7dSXVFtxp\n"
"0lq08EybkjgQAIwnvEu3L1qkBKWfqvNMGpcCOZAaRwizvdwuR2P1GCk8+HHC1iz/\n"
"0mAdZbd3ocsYwv1TI0JehViWTxIFXkd/5p2RXJeO2UeMtHVpsRCQ6LZNi4SXlAdm\n"
"zPHHEuxpGqxBmzYWswx9AT9+bwKBgQDLmEoLX+N+jjardIUjiIVVMWS5UQg4sNQF\n"
"fh1Ubgs9d3NdGhTBstOmVkYo/d9DGW1Enthxd6U0Jly5f2Ju1COriGzF5tpa9Q9F\n"
"PqiEioJEAstFGySU640hkAr4y/5l2USIyo6mTiQZ36lqBlCvb3LavY6Ag7ss0tTf\n"
"WXWFtjyh2wKBgQCYfqEPHwn9duzWMevSoWZwEvOROVmagoOC9HHmhUHM3cEth0SH\n"
"PR8oQu1Ec3qG+UqHUSTg+kBPwmquRXcSdlI75kxZWJQiHExMRU70kYeH7astJr3Y\n"
"MyBorzCMh33UCgrpx/pQ+4uwIXPlK0x7zegzn6IwL9B2gmSafapXAUtSyQKBgQCB\n"
"Sfprcr8zFPietOX/hKi3SyCdllnUNmbN/iJ+BUvaAssd6nwX7Yn+bXcsfNuU7sa2\n"
"9vCYTdR5Y4squTw3CTyFp6L7ofg0Hr9Nx9aYJKVIr0WKYww+Db+X+rMc/95Tqz+c\n"
"ZpVkAudmDuS00cHXRrz3L70Y2463jkNkepjpCqtCVQKBgCb4fFab5Qf4j7eZGpr5\n"
"PhtyAUuppBQHZ74snfiP3Xgpj0xLL1K9LrGCGAWfwAj6ADON6y/MwnNvFJD/+Agj\n"
"F3hJy3PnVHiisS0nX4UbkYI19509pc5iFPj4bfhWIMXvRdx+vIyeknvgK6Dyifco\n"
"CjsKZESRAfRYkXBIQvaiGqjm\n"
"-----END PRIVATE KEY-----\n";

static void wifi_event_handler(void* arg, esp_event_base_t event_base,
                               int32_t event_id, void* event_data) {
    if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_START) {
        esp_wifi_connect();
    } else if (event_base == WIFI_EVENT && event_id == WIFI_EVENT_STA_DISCONNECTED) {
        ESP_LOGW(TAG, "WiFi desconectado. Reconectando...");
        esp_wifi_connect();
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t* event = (ip_event_got_ip_t*) event_data;
        ESP_LOGI(TAG, "📶 WiFi conectado! IP: " IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

static void wifi_init(void) {
    wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));

    ESP_ERROR_CHECK(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                                               &wifi_event_handler, NULL));
    ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                                               &wifi_event_handler, NULL));

    wifi_config_t wifi_config = {
        .sta = {
            .ssid     = WIFI_SSID,
            .password = WIFI_PASSWORD,
        },
    };

    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());

    ESP_LOGI(TAG, "Aguardando conexão WiFi...");
    xEventGroupWaitBits(wifi_event_group, WIFI_CONNECTED_BIT,
                        pdFALSE, pdTRUE, portMAX_DELAY);
}

static void mqtt_event_handler(void* arg, esp_event_base_t event_base,
                               int32_t event_id, void* event_data) {
    esp_mqtt_event_handle_t event  = (esp_mqtt_event_handle_t) event_data;
    esp_mqtt_client_handle_t client = event->client;

    switch ((esp_mqtt_event_id_t)event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "🔐 MQTT conectado com mTLS via WSS!");
            esp_mqtt_client_publish(client, TOPIC_STATUS,
                "{\"status\":\"ONLINE\",\"phase\":\"5\",\"transport\":\"WSS\",\"tls\":\"mTLS\"}",
                0, 1, 0);
            break;
        case MQTT_EVENT_DISCONNECTED:
            ESP_LOGW(TAG, "MQTT desconectado.");
            break;
        case MQTT_EVENT_DATA:
            ESP_LOGI(TAG, "📥 Tópico: %.*s", event->topic_len, event->topic);
            ESP_LOGI(TAG, "   Payload: %.*s", event->data_len, event->data);
            break;
        case MQTT_EVENT_ERROR:
            ESP_LOGE(TAG, "Erro MQTT.");
            if (event->error_handle->error_type == MQTT_ERROR_TYPE_TCP_TRANSPORT) {
                ESP_LOGE(TAG, "  TLS error: 0x%x", event->error_handle->esp_tls_last_esp_err);
            }
            break;
        default:
            break;
    }
}

static void mqtt_init(void) {
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker = {
            .address.uri              = MQTT_BROKER_URI,
            .verification.certificate = CA_CERT,
        },
        .credentials = {
            .client_id               = MQTT_CLIENT_ID,
            .authentication.certificate = CLIENT_CERT,
            .authentication.key         = CLIENT_KEY,
        },
    };

    esp_mqtt_client_handle_t client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(client);
}

void app_main(void) {
    ESP_LOGI(TAG, "=== Phase 5: MQTT over WebSocket Secure (WSS + mTLS) ===");
    ESP_ERROR_CHECK(nvs_flash_init());
    wifi_init();
    mqtt_init();

    int count = 0;
    while (1) {
        ESP_LOGI(TAG, "Rodando... [%d]", count++);
        vTaskDelay(pdMS_TO_TICKS(30000));
    }
}