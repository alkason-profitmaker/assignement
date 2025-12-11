# PrintHub Station Display - ESP32 Firmware

Low-cost QR display for PrintHub self-service stations using ESP32 + TFT LCD.

## Bill of Materials (BOM) - ~₹1200-1500

| Component | Specs | Price (INR) | Buy Link |
|-----------|-------|-------------|----------|
| ESP32 DevKit V1 | 30-pin, WiFi+BT | ₹400-500 | [Robu.in](https://robu.in) |
| ILI9341 TFT LCD | 2.8", 320x240, SPI | ₹450-550 | [Robu.in](https://robu.in) |
| 5V 2A Power Adapter | Micro USB | ₹100-150 | Amazon |
| Jumper Wires | Female-Female | ₹50 | Local |
| **Total** | | **~₹1200** | |

## Wiring Diagram

```
ESP32 DevKit          ILI9341 TFT
-----------          -----------
3.3V         ───────  VCC
GND          ───────  GND
GPIO18       ───────  SCK (CLK)
GPIO23       ───────  MOSI (SDA)
GPIO5        ───────  CS
GPIO2        ───────  DC (RS)
GPIO4        ───────  RST
3.3V         ───────  LED (Backlight)
```

## Setup Instructions

### 1. Install PlatformIO

```bash
# Install VS Code extension "PlatformIO IDE"
# Or use CLI:
pip install platformio
```

### 2. Configure WiFi & Station

Edit `src/main.cpp`:

```cpp
const char* WIFI_SSID = "Your_WiFi_Name";
const char* WIFI_PASSWORD = "Your_WiFi_Password";

const char* SUPABASE_URL = "https://yourproject.supabase.co";
const char* STATION_ID = "uuid-from-database";
const char* STATION_KEY = "key-from-database";
```

### 3. Generate Station API Key

In Supabase SQL Editor:

```sql
-- Generate key for your station
UPDATE stations
SET station_api_key = generate_station_api_key(),
    display_type = 'esp32'
WHERE id = 'your-station-uuid'
RETURNING station_api_key;
```

### 4. Flash Firmware

```bash
cd station_firmware/esp32

# Build
pio run

# Upload (connect ESP32 via USB)
pio run --target upload

# Monitor serial output
pio device monitor
```

## How It Works

```
┌─────────────────┐
│   ESP32 Board   │
│                 │
│  ┌───────────┐  │     WiFi      ┌──────────────┐
│  │  2.8" TFT │  │◄────────────►│   Supabase   │
│  │  Display  │  │   Polling     │  station-poll│
│  └───────────┘  │   every 2s    │   endpoint   │
│                 │               └──────────────┘
└─────────────────┘
        │
        │ Shows QR Code
        ▼
   ┌─────────┐
   │  User   │ Scans with GPay/PhonePe
   │  Phone  │
   └─────────┘
```

## API Endpoint

The ESP32 polls this endpoint:

```
GET /functions/v1/station-poll?station_id=xxx&key=xxx

Response (has order):
{
  "has_order": true,
  "order": {
    "id": "uuid",
    "order_number": 123,
    "amount_rupees": 15,
    "qr_data": "upi://pay?...",
    "payment_status": "PENDING"
  }
}

Response (no order):
{
  "has_order": false
}
```

## Display States

1. **Connecting** - WiFi connection in progress
2. **Idle** - Ready, waiting for orders
3. **Order** - Shows amount + QR code
4. **Success** - Payment received, printing

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Blank screen | Check TFT wiring, especially CS and DC pins |
| WiFi fails | Verify SSID/password, check 2.4GHz (not 5GHz) |
| No orders shown | Verify station_id and station_key in code |
| QR not scanning | Increase display brightness, clean screen |

## Power Consumption

- Active polling: ~100mA @ 5V
- Can run on power bank for portable setup
- For permanent install, use 5V adapter

## Enclosure Ideas

- 3D printed case
- Acrylic stand
- Mount on printer using double-sided tape
- Old phone stand/holder

## Future Improvements

- [ ] OTA firmware updates
- [ ] Sleep mode between orders
- [ ] Buzzer for payment confirmation
- [ ] Status LED indicator
