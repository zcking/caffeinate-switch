#include <Arduino.h>

#include <atomic>

#include "Config.h"
#include "SwitchController.h"

namespace {

constexpr uint8_t LED_PWM_CHANNEL = 0;
constexpr uint32_t LED_PWM_FREQUENCY = 5000;
constexpr uint8_t LED_PWM_RESOLUTION = 8;
constexpr size_t MAX_RECORD_BYTES = 256;

SwitchController controller;
char inputBuffer[MAX_RECORD_BYTES + 1];
size_t inputLength = 0;
bool inputOverflow = false;
// 1 means connected, -1 means disconnected, and 0 means no pending event.
std::atomic<int8_t> serialConnectionEvent{0};

bool switchIsGrounded() {
  const int activeLevel = SWITCH_ACTIVE_LOW ? LOW : HIGH;
  return digitalRead(SWITCH_PIN) == activeLevel;
}

void readSerial() {
  while (Serial.available() > 0) {
    const char byte = static_cast<char>(Serial.read());
    if (byte == '\n') {
      if (!inputOverflow) controller.receiveLine({inputBuffer, inputLength});
      inputLength = 0;
      inputOverflow = false;
    } else if (!inputOverflow) {
      if (inputLength == MAX_RECORD_BYTES) {
        inputOverflow = true;
      } else {
        inputBuffer[inputLength++] = byte;
      }
    }
  }
}

void onUsbCdcEvent(void*, esp_event_base_t, int32_t eventId, void*) {
  if (eventId == ARDUINO_USB_CDC_CONNECTED) {
    serialConnectionEvent.store(1, std::memory_order_relaxed);
  } else if (eventId == ARDUINO_USB_CDC_DISCONNECTED) {
    serialConnectionEvent.store(-1, std::memory_order_relaxed);
  }
}

void handleSerialConnection(uint32_t nowMs) {
  const int8_t event = serialConnectionEvent.exchange(0, std::memory_order_relaxed);
  if (event > 0) {
    controller.serialConnected(nowMs);
  } else if (event < 0) {
    controller.serialDisconnected();
  }
}

}  // namespace

void setup() {
  pinMode(SWITCH_PIN, INPUT_PULLUP);
  Serial.begin(115200);  // Native USB CDC is enabled by platform build flags.
  // ESP32 Arduino USB CDC emits this when a host opens the serial connection.
  Serial.onEvent(onUsbCdcEvent);
  ledcSetup(LED_PWM_CHANNEL, LED_PWM_FREQUENCY, LED_PWM_RESOLUTION);
  ledcAttachPin(LED_PIN, LED_PWM_CHANNEL);
}

void loop() {
  const uint32_t nowMs = millis();
  handleSerialConnection(nowMs);
  controller.sample(switchIsGrounded(), nowMs);
  readSerial();
  controller.tick(nowMs);
  const std::string outbound = controller.takeOutbound();
  if (!outbound.empty()) Serial.print(outbound.c_str());
  ledcWrite(LED_PWM_CHANNEL, controller.ledBrightness(nowMs));
}
