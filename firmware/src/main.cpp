#include <Arduino.h>

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

}  // namespace

void setup() {
  pinMode(SWITCH_PIN, INPUT_PULLUP);
  Serial.begin(115200);  // Native USB CDC is enabled by platform build flags.
  ledcSetup(LED_PWM_CHANNEL, LED_PWM_FREQUENCY, LED_PWM_RESOLUTION);
  ledcAttachPin(LED_PIN, LED_PWM_CHANNEL);
  Serial.print("HELLO 1\n");
}

void loop() {
  const uint32_t nowMs = millis();
  controller.sample(switchIsGrounded(), nowMs);
  readSerial();
  controller.tick(nowMs);
  const std::string outbound = controller.takeOutbound();
  if (!outbound.empty()) Serial.print(outbound.c_str());
  ledcWrite(LED_PWM_CHANNEL, controller.ledBrightness(nowMs));
}
