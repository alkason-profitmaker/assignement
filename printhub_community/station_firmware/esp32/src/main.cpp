/**
 * PrintHub Station Display Firmware
 * Hardware: ESP32 + ILI9341 2.8" TFT (320x240)
 * Cost: ~₹1200-1500
 *
 * Wiring:
 *   ESP32    ILI9341
 *   ------   -------
 *   3.3V  →  VCC
 *   GND   →  GND
 *   GPIO18 → SCK
 *   GPIO23 → MOSI
 *   GPIO5  → CS
 *   GPIO2  → DC
 *   GPIO4  → RST
 *   3.3V  →  LED
 */

#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <TFT_eSPI.h>
#include <qrcode.h>

// ============================================
// CONFIGURATION - Update these values!
// ============================================
const char* WIFI_SSID = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* SUPABASE_URL = "https://YOUR_PROJECT.supabase.co";
const char* STATION_ID = "YOUR_STATION_UUID";
const char* STATION_KEY = "YOUR_STATION_API_KEY";  // From database

// Polling interval (milliseconds)
const unsigned long POLL_INTERVAL = 2000;  // 2 seconds

// ============================================
// Global Variables
// ============================================
TFT_eSPI tft = TFT_eSPI();

String currentOrderId = "";
String currentQrData = "";
int currentAmount = 0;
unsigned long lastPollTime = 0;
bool wifiConnected = false;

// Colors
#define COLOR_BG       TFT_WHITE
#define COLOR_PRIMARY  0x1E3C  // Dark blue
#define COLOR_SUCCESS  0x07E0  // Green
#define COLOR_ERROR    0xF800  // Red
#define COLOR_TEXT     TFT_BLACK
#define COLOR_GRAY     0x7BEF

// ============================================
// Function Declarations
// ============================================
void setupWiFi();
void setupDisplay();
void showIdleScreen();
void showConnectingScreen();
void showErrorScreen(const char* message);
void showOrderScreen(int amount, const char* qrData);
void showPaymentSuccess();
void pollForOrders();
void drawQRCode(const char* data, int x, int y, int size);

// ============================================
// Setup
// ============================================
void setup() {
  Serial.begin(115200);
  Serial.println("\n\nPrintHub Station Display v1.0");

  setupDisplay();
  showConnectingScreen();
  setupWiFi();

  if (wifiConnected) {
    showIdleScreen();
  }
}

// ============================================
// Main Loop
// ============================================
void loop() {
  // Check WiFi connection
  if (WiFi.status() != WL_CONNECTED) {
    if (wifiConnected) {
      wifiConnected = false;
      showErrorScreen("WiFi Lost");
      setupWiFi();
    }
    return;
  }

  // Poll for orders
  if (millis() - lastPollTime >= POLL_INTERVAL) {
    pollForOrders();
    lastPollTime = millis();
  }
}

// ============================================
// WiFi Setup
// ============================================
void setupWiFi() {
  Serial.print("Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    wifiConnected = true;
    Serial.println("\nWiFi connected!");
    Serial.print("IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection failed!");
    showErrorScreen("WiFi Failed");
  }
}

// ============================================
// Display Setup
// ============================================
void setupDisplay() {
  tft.init();
  tft.setRotation(1);  // Landscape
  tft.fillScreen(COLOR_BG);
}

// ============================================
// Screen States
// ============================================
void showConnectingScreen() {
  tft.fillScreen(COLOR_BG);
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextSize(2);
  tft.setCursor(60, 100);
  tft.println("PrintHub");
  tft.setTextColor(COLOR_GRAY);
  tft.setTextSize(1);
  tft.setCursor(70, 130);
  tft.println("Connecting to WiFi...");
}

void showIdleScreen() {
  currentOrderId = "";
  currentQrData = "";
  currentAmount = 0;

  tft.fillScreen(COLOR_BG);

  // Logo/Title
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextSize(2);
  tft.setCursor(80, 60);
  tft.println("PrintHub");

  // Status
  tft.setTextColor(COLOR_GRAY);
  tft.setTextSize(1);
  tft.setCursor(65, 100);
  tft.println("Ready for orders");

  // Instructions
  tft.setCursor(30, 140);
  tft.println("Create order in PrintHub app");
  tft.setCursor(40, 160);
  tft.println("QR will appear here");

  // Station info
  tft.setTextSize(1);
  tft.setCursor(10, 220);
  tft.print("Station: ");
  tft.println(STATION_ID);
}

void showErrorScreen(const char* message) {
  tft.fillScreen(COLOR_BG);
  tft.setTextColor(COLOR_ERROR);
  tft.setTextSize(2);
  tft.setCursor(100, 100);
  tft.println("Error");
  tft.setTextSize(1);
  tft.setCursor(60, 130);
  tft.println(message);
}

void showOrderScreen(int amount, const char* qrData) {
  tft.fillScreen(COLOR_BG);

  // Amount display
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextSize(3);
  tft.setCursor(20, 10);
  tft.print("Rs ");
  tft.println(amount);

  // QR Code (centered)
  if (strlen(qrData) > 0) {
    drawQRCode(qrData, 85, 50, 150);
  } else {
    tft.setTextColor(COLOR_GRAY);
    tft.setTextSize(1);
    tft.setCursor(80, 120);
    tft.println("QR Loading...");
  }

  // Instructions
  tft.setTextColor(COLOR_TEXT);
  tft.setTextSize(1);
  tft.setCursor(50, 210);
  tft.println("Scan with any UPI app");
}

void showPaymentSuccess() {
  tft.fillScreen(COLOR_SUCCESS);
  tft.setTextColor(TFT_WHITE);
  tft.setTextSize(2);
  tft.setCursor(70, 80);
  tft.println("PAYMENT");
  tft.setCursor(60, 110);
  tft.println("RECEIVED!");

  tft.setTextSize(1);
  tft.setCursor(50, 160);
  tft.println("Printing your document...");
  tft.setCursor(60, 180);
  tft.println("Please wait nearby");
}

// ============================================
// QR Code Drawing
// ============================================
void drawQRCode(const char* data, int x, int y, int size) {
  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(6)];

  // Generate QR code (version 6 = 41x41 modules)
  qrcode_initText(&qrcode, qrcodeData, 6, ECC_MEDIUM, data);

  // Calculate scale
  int scale = size / qrcode.size;
  int offsetX = x + (size - qrcode.size * scale) / 2;
  int offsetY = y + (size - qrcode.size * scale) / 2;

  // Draw white background
  tft.fillRect(x, y, size, size, TFT_WHITE);

  // Draw QR modules
  for (int qy = 0; qy < qrcode.size; qy++) {
    for (int qx = 0; qx < qrcode.size; qx++) {
      if (qrcode_getModule(&qrcode, qx, qy)) {
        tft.fillRect(
          offsetX + qx * scale,
          offsetY + qy * scale,
          scale, scale,
          COLOR_PRIMARY
        );
      }
    }
  }
}

// ============================================
// API Polling
// ============================================
void pollForOrders() {
  HTTPClient http;

  // Build URL
  String url = String(SUPABASE_URL) + "/functions/v1/station-poll";
  url += "?station_id=" + String(STATION_ID);
  url += "&key=" + String(STATION_KEY);

  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(5000);  // 5 second timeout

  int httpCode = http.GET();

  if (httpCode == 200) {
    String payload = http.getString();

    // Parse JSON
    StaticJsonDocument<1024> doc;
    DeserializationError error = deserializeJson(doc, payload);

    if (!error) {
      bool hasOrder = doc["has_order"] | false;

      if (hasOrder) {
        JsonObject order = doc["order"];
        String orderId = order["id"] | "";
        int amount = order["amount_rupees"] | 0;
        String qrData = order["qr_data"] | "";
        String paymentStatus = order["payment_status"] | "";

        // New order or updated order
        if (orderId != currentOrderId || qrData != currentQrData) {
          currentOrderId = orderId;
          currentAmount = amount;
          currentQrData = qrData;

          Serial.print("New order: ");
          Serial.print(orderId);
          Serial.print(" Amount: Rs ");
          Serial.println(amount);

          showOrderScreen(amount, qrData.c_str());
        }
      } else {
        // No pending order
        if (currentOrderId != "") {
          // Order was paid or cancelled - check status
          Serial.println("Order completed or cancelled");
          showPaymentSuccess();
          delay(5000);  // Show success for 5 seconds
          showIdleScreen();
        }
      }
    } else {
      Serial.print("JSON parse error: ");
      Serial.println(error.c_str());
    }
  } else {
    Serial.print("HTTP error: ");
    Serial.println(httpCode);
  }

  http.end();
}
