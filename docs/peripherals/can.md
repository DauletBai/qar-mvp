# CAN 2.0B Controller (Phase 1)

## Goals
- Support basic CAN 2.0B operation up to 1 Mbps.
- Provide TX/RX mailboxes, acceptance filters, and interrupt hooks.
- Initial implementation targets single CAN interface (CAN0 @ `0x4000_3000`).

## Register Map (offsets from base)

| Offset | Name          | Description |
|--------|---------------|-------------|
| 0x00   | CTRL          | Bit0: enable, bit1: loopback, bit2: listen-only, bit3: auto-retransmit. |
| 0x04   | STATUS        | Bit0: RX pending, bit1: TX idle, bit2: error passive, bit3: bus-off, bit4: arbitration lost. |
| 0x08   | BITTIME       | Timing register (`BRP`, `SEG1`, `SEG2`, `SJW`). |
| 0x0C   | ERR_COUNTER   | TEC (15:8) / REC (7:0). |
| 0x10   | IRQ_EN        | Interrupt enables (RX, TX complete, errors). |
| 0x14   | IRQ_STATUS    | Interrupt status (write-1-to-clear). |
| 0x18   | FILTER0_ID    | Acceptance filter ID (11/29-bit). |
| 0x1C   | FILTER0_MASK  | Acceptance mask. |
| 0x20   | TX_MAILBOX_ID | TX identifier (bit 31 for extended frame). |
| 0x24   | TX_MAILBOX_DLC| DLC and RTR bits. |
| 0x28   | TX_MAILBOX_DATA0 | First word of payload. |
| 0x2C   | TX_MAILBOX_DATA1 | Second word of payload. |
| 0x30   | TX_CMD        | Bit0: request to send. |
| 0x34   | RX_MAILBOX_ID | Last received identifier. |
| 0x38   | RX_MAILBOX_DLC| Last received DLC/RTR. |
| 0x3C   | RX_MAILBOX_DATA0 | Received payload word 0. |
| 0x40   | RX_MAILBOX_DATA1 | Received payload word 1. |

## Behaviour Summary
- Firmware writes TX mailboxes then sets `TX_CMD`. Controller arbitrates and transmits when bus idle; completion sets `IRQ_STATUS[1]`.
- RX path filters frames based on filter/mask; accepted frames populate RX mailbox and assert `IRQ_STATUS[0]`.
- Error conditions update `ERR_COUNTER`, `STATUS`, and corresponding IRQ bits.
- Future revisions: multiple filters/mailboxes, CAN-FD, DMA support.

See `devkit/examples/can_loopback.qar` and `scripts/run_can.sh` for a loopback regression, and `devkit/hal/can.h` for a minimal C HAL.
