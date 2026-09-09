# Caffeinate Switch serial protocol

The firmware and Mac agent exchange UTF-8 records over USB CDC serial. Each
record is ASCII text terminated by a single newline (`\n`). A record, excluding
its terminator, must be at most 256 bytes. `ProtocolMessage.encoded` represents
the record without that newline. Because `ProtocolMessage` cases are public,
the encoder canonicalizes constructible invalid values: every `HELLO` encodes
as version `1`, and error-code whitespace becomes `_`; an error code is also
truncated as needed to keep its complete record within 256 bytes.

## Records

```text
HELLO 1
STATE <sequence> ON|OFF
PING <sequence>
ACK <sequence> ON|OFF
ERROR <sequence> <code>
```

`HELLO` declares protocol version 1; all other versions are unsupported.
`<sequence>` is an unsigned decimal integer. State values and record names are
uppercase. Error codes are a single, non-whitespace token.

Examples:

```text
HELLO 1
STATE 7 ON
PING 7
ACK 7 ON
ERROR 7 CHILD_EXIT
```

## Delivery and retry behavior

Firmware sends a `STATE` record after a stable physical rocker transition and
retries that same record every second until it receives an `ACK` with the same
sequence and state. Sequence matching prevents stale acknowledgements from
confirming the switch. Firmware sends `PING` heartbeats every three seconds.
After a USB reconnect, firmware reconciles from the current physical rocker
state. Receivers safely ignore malformed or oversized records.
