# CAN 2.0B Controller (Phase 1)

## Goals
- Support basic CAN 2.0B operation up to 1 Mbps.
- Provide TX/RX mailboxes, acceptance filters, and interrupt hooks.
- Initial implementation targets single CAN interface (CAN0 @ `0x4000_3000`).

## Register Map (offsets from base)

| Offset | Name          | Description |
|--------|---------------|-------------|
| 0x00   | CTRL          | Bit0: enable, bit1: loopback (internal self-test). |
| 0x04   | STATUS        | Bit0: RX pending (FIFO not empty), bit1: TX idle, bit2: RX overflow (FIFO full drop), remaining bits reserved. |
| 0x08   | BITTIME       | Timing register (`BRP`, `SEG1`, `SEG2`, `SJW`). |
| 0x0C   | ERR_COUNTER   | TEC (15:8) / REC (7:0). |
| 0x10   | IRQ_EN        | Interrupt enables (bit0 RX ready, bit1 TX done, bit2 overflow). |
| 0x14   | IRQ_STATUS    | Interrupt status (write-1-to-clear). |
| 0x18   | FILTER0_ID    | Acceptance filter ID (11/29-bit). |
| 0x1C   | FILTER0_MASK  | Acceptance mask. |
| 0x20   | TX_MAILBOX_ID | TX identifier (bit 31 for extended frame). |
| 0x24   | TX_MAILBOX_DLC| DLC and RTR bits. |
| 0x28   | TX_MAILBOX_DATA0 | First word of payload. |
| 0x2C   | TX_MAILBOX_DATA1 | Second word of payload. |
| 0x30   | TX_CMD        | Bit0: request to send (immediate loopback in current revision). |
| 0x34   | RX_MAILBOX_ID | Head entry identifier (non-destructive read). |
| 0x38   | RX_MAILBOX_DLC| Head entry DLC/RTR. |
| 0x3C   | RX_MAILBOX_DATA0 | Head entry payload word 0. |
| 0x40   | RX_MAILBOX_DATA1 | Head entry payload word 1. |
| 0x44   | RX_FIFO_CTRL  | Bits0-2: pending entry count, bit3: overflow flag. Write bit0 to pop one entry, bit1 to flush FIFO, bit2 to clear overflow flag. |

## Behaviour Summary
- Firmware writes TX mailboxes then sets `TX_CMD`. In loopback mode the controller immediately copies the frame into the RX FIFO, asserts `STATUS[0]`, and sets `IRQ_STATUS[0]`. Bit1 shows when the transmit path is idle and raises `IRQ_STATUS[1]`.
- The RX FIFO holds up to four frames. Firmware reads ID/DLC/DATA registers without altering the FIFO head, then writes `RX_FIFO_CTRL` bit0 to pop the entry (or bit1 to flush all pending frames). If the FIFO is full when a new frame arrives, the overflow flag latches in `STATUS[2]`/`IRQ_STATUS[2]`.
- Future revisions: external CAN PHY connection, listen-only mode, additional filters/mailboxes, CAN-FD, DMA support.

## Loopback Demo
`scripts/run_can.sh` assembles `devkit/examples/can_loopback.qar`, which enables loopback mode, transmits two frames (`0x123` with a single word payload and `0x321` with two words), and stores the received IDs + payload words into DMEM[0..5]. Each frame read uses the new `CAN_RX_FIFO_CTRL` pop command so firmware can read ID/data in any order without racing the FIFO pointer. The `qar_core_can_tb` harness checks those locations to make sure RX interrupts fire and the payload path works for single- and dual-word DLC values.

See `devkit/examples/can_loopback.qar` and `scripts/run_can.sh` for the regression, and `devkit/hal/can.h` for a minimal C HAL.
