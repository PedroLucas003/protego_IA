/*
 * ============================================================
 *  Phase 3 — ESP-IDF + TLS com validação real do certificado CA
 *  Cliente MQTT nativo do ESP-IDF (mqtt_client)
 *  Certificado CA embutido como string no código
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

static const char* TAG = "PHASE3";

// ─── WiFi ────────────────────────────────────────────────────
#define WIFI_SSID     "PEDRO_JDN"
#define WIFI_PASSWORD "03072003"
#define WIFI_CONNECTED_BIT BIT0

static EventGroupHandle_t wifi_event_group;

// ─── MQTT ────────────────────────────────────────────────────
#define MQTT_BROKER_URI "mqtts://kodama.proxy.rlwy.net:38909"
#define MQTT_CLIENT_ID  "esp32-phase3"
#define TOPIC_STATUS    "policia/cam01/status"

// ─── Certificado CA (validação real — Phase 3) ───────────────
static const char* CA_CERT = \
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

// ─── WiFi Event Handler ───────────────────────────────────────
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

// ─── WiFi Init ────────────────────────────────────────────────
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

// ─── MQTT Event Handler ───────────────────────────────────────
static void mqtt_event_handler(void* arg, esp_event_base_t event_base,
                               int32_t event_id, void* event_data) {
    esp_mqtt_event_handle_t event  = (esp_mqtt_event_handle_t) event_data;
    esp_mqtt_client_handle_t client = event->client;

    switch ((esp_mqtt_event_id_t)event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "🔐 MQTT conectado com TLS!");
            esp_mqtt_client_publish(client, TOPIC_STATUS,
                "{\"status\":\"ONLINE\",\"phase\":\"3\",\"tls\":\"CA_validado\"}",
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

// ─── MQTT Init ────────────────────────────────────────────────
static void mqtt_init(void) {
    esp_mqtt_client_config_t mqtt_cfg = {
        .broker = {
            .address.uri        = MQTT_BROKER_URI,
            .verification.certificate = CA_CERT,  // validação real do CA
        },
        .credentials = {
            .client_id = MQTT_CLIENT_ID,
        },
    };

    esp_mqtt_client_handle_t client = esp_mqtt_client_init(&mqtt_cfg);
    esp_mqtt_client_register_event(client, ESP_EVENT_ANY_ID, mqtt_event_handler, NULL);
    esp_mqtt_client_start(client);
}

// ─── Main ─────────────────────────────────────────────────────
void app_main(void) {
    // Print imediato antes de qualquer inicialização
    printf("=== BOOT ESP32 PHASE 3 ===\n");
    printf("Iniciando...\n");
    fflush(stdout);
    
    vTaskDelay(pdMS_TO_TICKS(2000));
    printf("Inicializando NVS...\n");
    fflush(stdout);
    
    ESP_LOGI(TAG, "=== Phase 3: ESP-IDF + TLS com validação real do CA ===");

    ESP_ERROR_CHECK(nvs_flash_init());
    
    printf("NVS OK. Conectando WiFi...\n");
    fflush(stdout);
    
    wifi_init();
    mqtt_init();

    int count = 0;
    while (1) {
        printf("Rodando... [%d]\n", count++);
        fflush(stdout);
        vTaskDelay(pdMS_TO_TICKS(5000));
    }
}