#pragma once

// Safe initial defaults for ESP32-S3 DevKitC-1 and classic ESP32 DevKit
// (ESP-WROOM-32). Verify these pins against the exact board silkscreen and
// pinout before applying power; vendor labels vary.
constexpr int SWITCH_PIN = 4;
constexpr int LED_PIN = 5;
constexpr bool SWITCH_ACTIVE_LOW = true;
