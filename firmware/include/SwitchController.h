#pragma once

#include <cstdint>
#include <string>
#include <string_view>

enum class ConfirmedState { Unknown, Off, On, Error };

class SwitchController {
 public:
  static constexpr uint32_t DEBOUNCE_MS = 40;
  static constexpr uint32_t RETRY_MS = 1000;
  static constexpr uint32_t HEARTBEAT_MS = 3000;

  void sample(bool grounded, uint32_t nowMs);
  void serialConnected(uint32_t nowMs);
  void serialDisconnected();
  void receiveLine(std::string_view line);
  void tick(uint32_t nowMs);
  std::string takeOutbound();
  uint8_t ledBrightness(uint32_t nowMs) const;

  ConfirmedState confirmedState() const { return confirmedState_; }

 private:
  static bool elapsed(uint32_t nowMs, uint32_t sinceMs, uint32_t intervalMs);
  void queueHello();
  void queueState(uint32_t nowMs);
  void queuePing(uint32_t nowMs);

  bool hasCandidate_ = false;
  bool candidateGrounded_ = false;
  bool hasStableState_ = false;
  bool stableGrounded_ = false;
  bool serialConnected_ = false;
  bool awaitingAck_ = false;
  uint32_t candidateSinceMs_ = 0;
  uint32_t sequence_ = 0;
  uint32_t lastStateSentMs_ = 0;
  uint32_t lastHeartbeatMs_ = 0;
  ConfirmedState confirmedState_ = ConfirmedState::Unknown;
  std::string outbound_;
};
