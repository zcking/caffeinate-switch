#include <unity.h>

#include "Config.h"
#include "SwitchController.h"

static_assert(SwitchController::DEBOUNCE_MS == 40);
static_assert(SwitchController::RETRY_MS == 1000);
static_assert(SwitchController::HEARTBEAT_MS == 3000);
static_assert(SWITCH_PIN == 4);
static_assert(LED_PIN == 5);
static_assert(SWITCH_ACTIVE_LOW);

void test_state_changes_only_after_40_ms_stable() {
  SwitchController c;
  c.sample(true, 0); c.sample(false, 10); c.sample(true, 20);
  TEST_ASSERT_TRUE(c.takeOutbound().empty());
  c.sample(true, 61);
  TEST_ASSERT_EQUAL_STRING("STATE 1 ON\n", c.takeOutbound().c_str());
}

void test_stale_acknowledgement_cannot_confirm_led() {
  SwitchController c;
  c.serialConnected(0); c.takeOutbound();
  c.sample(true, 0); c.sample(true, 41); c.takeOutbound();
  c.receiveLine("ACK 0 ON");
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Unknown);
}

void test_matching_acknowledgement_confirms_requested_state() {
  SwitchController c;
  c.serialConnected(0); c.takeOutbound();
  c.sample(false, 0); c.sample(false, 40); c.takeOutbound();
  c.receiveLine("ACK 1 OFF");
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Off);
  TEST_ASSERT_EQUAL_UINT8(0, c.ledBrightness(500));
}

void test_pending_state_retries_every_second_and_heartbeats_every_three_seconds() {
  SwitchController c;
  c.serialConnected(0); c.takeOutbound();
  // Debounce completes at t=40, which is also lastStateSentMs_ for the first STATE.
  c.sample(true, 0); c.sample(true, 40); c.takeOutbound();
  c.tick(1039);
  TEST_ASSERT_TRUE(c.takeOutbound().empty());
  c.tick(1040);
  TEST_ASSERT_EQUAL_STRING("STATE 1 ON\n", c.takeOutbound().c_str());
  c.tick(3000);
  TEST_ASSERT_EQUAL_STRING("STATE 1 ON\nPING 1\n", c.takeOutbound().c_str());
}

void test_error_and_unknown_led_patterns_use_required_timing() {
  SwitchController c;
  TEST_ASSERT_EQUAL_UINT8(0, c.ledBrightness(0));
  TEST_ASSERT_EQUAL_UINT8(255, c.ledBrightness(1000));
  c.serialConnected(0); c.takeOutbound();
  c.sample(true, 0); c.sample(true, 40); c.takeOutbound();
  c.receiveLine("ERROR 1 CHILD_EXIT");
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Error);
  TEST_ASSERT_EQUAL_UINT8(255, c.ledBrightness(124));
  TEST_ASSERT_EQUAL_UINT8(0, c.ledBrightness(125));
}

void test_disconnect_and_reconnect_pulse_until_current_state_is_acknowledged() {
  SwitchController c;
  c.serialConnected(0); c.takeOutbound();
  c.sample(true, 0); c.sample(true, 40); c.takeOutbound();
  c.receiveLine("ACK 1 ON");
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::On);
  TEST_ASSERT_EQUAL_UINT8(255, c.ledBrightness(250));

  c.serialDisconnected();
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Unknown);
  TEST_ASSERT_EQUAL_UINT8(0, c.ledBrightness(0));
  TEST_ASSERT_EQUAL_UINT8(255, c.ledBrightness(1000));
  c.receiveLine("ACK 1 ON");
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Unknown);

  c.serialConnected(100);
  TEST_ASSERT_EQUAL_STRING("HELLO 1\nSTATE 1 ON\n", c.takeOutbound().c_str());
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Unknown);
  TEST_ASSERT_EQUAL_UINT8(255, c.ledBrightness(1000));

  c.receiveLine("ACK 0 ON");
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Unknown);
  c.receiveLine("ACK 1 ON");
  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::On);
  TEST_ASSERT_EQUAL_UINT8(255, c.ledBrightness(250));
}

void test_session_version_error_uses_sequence_zero_and_blinks_rapidly() {
  SwitchController c;
  c.serialConnected(0); c.takeOutbound();
  c.sample(true, 0); c.sample(true, 40); c.takeOutbound();

  c.receiveLine("ERROR 0 VERSION");

  TEST_ASSERT_TRUE(c.confirmedState() == ConfirmedState::Error);
  TEST_ASSERT_EQUAL_UINT8(255, c.ledBrightness(124));
  TEST_ASSERT_EQUAL_UINT8(0, c.ledBrightness(125));
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_state_changes_only_after_40_ms_stable);
  RUN_TEST(test_stale_acknowledgement_cannot_confirm_led);
  RUN_TEST(test_matching_acknowledgement_confirms_requested_state);
  RUN_TEST(test_pending_state_retries_every_second_and_heartbeats_every_three_seconds);
  RUN_TEST(test_error_and_unknown_led_patterns_use_required_timing);
  RUN_TEST(test_disconnect_and_reconnect_pulse_until_current_state_is_acknowledged);
  RUN_TEST(test_session_version_error_uses_sequence_zero_and_blinks_rapidly);
  return UNITY_END();
}
