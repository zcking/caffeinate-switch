#include "SwitchController.h"

#include <charconv>
#include <cmath>

namespace {

constexpr double PI = 3.14159265358979323846;

const char* stateName(bool grounded) {
  return grounded ? "ON" : "OFF";
}

bool parseState(std::string_view value, bool& grounded) {
  if (value == "ON") {
    grounded = true;
    return true;
  }
  if (value == "OFF") {
    grounded = false;
    return true;
  }
  return false;
}

bool parseSequence(std::string_view value, uint32_t& sequence) {
  if (value.empty()) return false;
  const char* begin = value.data();
  const char* end = begin + value.size();
  const auto result = std::from_chars(begin, end, sequence);
  return result.ec == std::errc{} && result.ptr == end;
}

}  // namespace

bool SwitchController::elapsed(uint32_t nowMs, uint32_t sinceMs,
                               uint32_t intervalMs) {
  return static_cast<uint32_t>(nowMs - sinceMs) >= intervalMs;
}

void SwitchController::sample(bool grounded, uint32_t nowMs) {
  if (!hasCandidate_ || grounded != candidateGrounded_) {
    candidateGrounded_ = grounded;
    candidateSinceMs_ = nowMs;
    hasCandidate_ = true;
    return;
  }

  if (elapsed(nowMs, candidateSinceMs_, DEBOUNCE_MS) &&
      (!hasStableState_ || grounded != stableGrounded_)) {
    stableGrounded_ = grounded;
    hasStableState_ = true;
    ++sequence_;
    awaitingAck_ = true;
    confirmedState_ = ConfirmedState::Unknown;
    queueState(nowMs);
  }
}

void SwitchController::receiveLine(std::string_view line) {
  const size_t first = line.find(' ');
  if (first == std::string_view::npos) return;
  const std::string_view type = line.substr(0, first);
  const size_t second = line.find(' ', first + 1);
  if (second == std::string_view::npos) return;

  uint32_t receivedSequence = 0;
  if (!parseSequence(line.substr(first + 1, second - first - 1), receivedSequence)) {
    return;
  }
  const std::string_view remainder = line.substr(second + 1);

  if (type == "ACK") {
    bool receivedGrounded = false;
    if (!parseState(remainder, receivedGrounded) || !awaitingAck_ ||
        receivedSequence != sequence_ || receivedGrounded != stableGrounded_) {
      return;
    }
    awaitingAck_ = false;
    confirmedState_ = receivedGrounded ? ConfirmedState::On : ConfirmedState::Off;
  } else if (type == "ERROR" && receivedSequence == sequence_ &&
             !remainder.empty() && remainder.find_first_of(" \t\r\n") == std::string_view::npos) {
    awaitingAck_ = false;
    confirmedState_ = ConfirmedState::Error;
  }
}

void SwitchController::tick(uint32_t nowMs) {
  if (awaitingAck_ && elapsed(nowMs, lastStateSentMs_, RETRY_MS)) {
    queueState(nowMs);
  }
  if (elapsed(nowMs, lastHeartbeatMs_, HEARTBEAT_MS)) {
    queuePing(nowMs);
  }
}

std::string SwitchController::takeOutbound() {
  std::string outbound;
  outbound.swap(outbound_);
  return outbound;
}

uint8_t SwitchController::ledBrightness(uint32_t nowMs) const {
  switch (confirmedState_) {
    case ConfirmedState::On:
      return 255;
    case ConfirmedState::Off:
      return 0;
    case ConfirmedState::Error:
      return (nowMs % 250) < 125 ? 255 : 0;
    case ConfirmedState::Unknown: {
      const double phase = static_cast<double>(nowMs % 2000) / 2000.0;
      return static_cast<uint8_t>((std::sin(phase * 2.0 * PI - PI / 2.0) + 1.0) * 127.5);
    }
  }
  return 0;
}

void SwitchController::queueState(uint32_t nowMs) {
  outbound_ += "STATE " + std::to_string(sequence_) + " " + stateName(stableGrounded_) + "\n";
  lastStateSentMs_ = nowMs;
}

void SwitchController::queuePing(uint32_t nowMs) {
  outbound_ += "PING " + std::to_string(sequence_) + "\n";
  lastHeartbeatMs_ = nowMs;
}
