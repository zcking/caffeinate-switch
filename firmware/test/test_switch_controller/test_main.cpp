#define CATCH_CONFIG_MAIN
#include <catch2/catch.hpp>

#include "SwitchController.h"

TEST_CASE("state changes only after 40 ms stable") {
  SwitchController c;
  c.sample(true, 0); c.sample(false, 10); c.sample(true, 20);
  CHECK(c.takeOutbound().empty());
  c.sample(true, 61);
  CHECK(c.takeOutbound() == "STATE 1 ON\n");
}

TEST_CASE("stale acknowledgement cannot confirm LED") {
  SwitchController c;
  c.sample(true, 0); c.sample(true, 41); c.takeOutbound();
  c.receiveLine("ACK 0 ON");
  CHECK(c.confirmedState() == ConfirmedState::Unknown);
}

TEST_CASE("matching acknowledgement confirms the requested state") {
  SwitchController c;
  c.sample(false, 0); c.sample(false, 40); c.takeOutbound();
  c.receiveLine("ACK 1 OFF");
  CHECK(c.confirmedState() == ConfirmedState::Off);
  CHECK(c.ledBrightness(500) == 0);
}

TEST_CASE("pending state retries every second and heartbeats every three seconds") {
  SwitchController c;
  c.sample(true, 0); c.sample(true, 40); c.takeOutbound();
  c.tick(999);
  CHECK(c.takeOutbound().empty());
  c.tick(1000);
  CHECK(c.takeOutbound() == "STATE 1 ON\n");
  c.tick(3000);
  CHECK(c.takeOutbound() == "STATE 1 ON\nPING 1\n");
}

TEST_CASE("error and unknown LED patterns use the required timing") {
  SwitchController c;
  CHECK(c.ledBrightness(0) == 0);
  CHECK(c.ledBrightness(1000) == 255);
  c.sample(true, 0); c.sample(true, 40); c.takeOutbound();
  c.receiveLine("ERROR 1 CHILD_EXIT");
  CHECK(c.confirmedState() == ConfirmedState::Error);
  CHECK(c.ledBrightness(124) == 255);
  CHECK(c.ledBrightness(125) == 0);
}
