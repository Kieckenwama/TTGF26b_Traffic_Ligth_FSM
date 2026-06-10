# Silicon Testing Procedure: Traffic Light Controller

## Overview

This document describes the procedure for testing the fabricated silicon
implementation of the Traffic Light Controller. The design implements a
finite-state machine (FSM) with five states (S0–S4) controlling three
traffic lights: main road, side road, and pedestrian.

The procedure covers reset behaviour, the normal state sequence, and the
pedestrian request path. Each test specifies the input signals to be applied,
the expected output signals, and a column for recording the measured result
during silicon testing.

---

## Device Under Test

**Module:** `top`  
**Shuttle:** Tiny Tapeout GF-26b  
**Process node:** GlobalFoundries GF180MCU (180 nm, PDK: gf180mcuD)  
**Clock frequency:** 12 MHz (period: 83.3 ns)  
**Core supply voltage:** 1.8 V  
**I/O supply voltage:** 3.3 V  

### Pin Assignment

| Signal        | Direction | Description                         |
|---------------|-----------|-------------------------------------|
| `clk`         | Input     | 12 MHz system clock                 |
| `rst_n`       | Input     | Asynchronous reset, active low      |
| `ped_req`     | Input     | Pedestrian push-button, active high |
| `main_green`  | Output    | Main road green light               |
| `main_yellow` | Output    | Main road yellow light              |
| `main_red`    | Output    | Main road red light                 |
| `side_green`  | Output    | Side road green light               |
| `side_yellow` | Output    | Side road yellow light              |
| `side_red`    | Output    | Side road red light                 |
| `ped_green`   | Output    | Pedestrian green light              |
| `ped_red`     | Output    | Pedestrian red light                |

---

## External Hardware

The following external circuitry is required to perform the measurements:

- **Clock source:** Signal generator or oscillator providing a stable 12 MHz
  clock with CMOS-compatible voltage levels (0 V / 3.3 V for I/O). Rise and
  fall times must be below 5 ns.
- **Reset circuit:** Pull-up resistor (10 kΩ) to VDDIO (3.3 V) on `rst_n`,
  with a push-button to GND for manual reset assertion.
- **Pedestrian button:** Push-button with 10 kΩ pull-down resistor to GND
  on `ped_req`. Button connects to VDDIO (3.3 V) when pressed.
- **Output monitoring:** Logic analyser with at least 11 channels
  (1 clock + 10 signal outputs), with input threshold configurable for
  3.3 V CMOS levels.

---

## Required Instruments

| Instrument | Minimum Specification |
|---|---|
| Signal generator | Frequency up to 12 MHz, 3.3 V CMOS output levels |
| Logic analyser | ≥ 11 channels, ≥ 100 MHz sampling rate, threshold configurable to 1.65 V |
| DC power supply (core) | 1.8 V ± 5 %, current limit 50 mA |
| DC power supply (I/O) | 3.3 V ± 5 %, current limit 100 mA |
| Multimeter | For supply voltage verification before powering up |

---

## Test 1: Reset Behaviour

**Purpose:** Verify REQ-01 — after reset deassertion, the FSM enters S0
(main road green, all others red) within one clock cycle.

**Procedure:** Assert `rst_n = 0` for at least two clock cycles (> 170 ns),
then deassert (`rst_n = 1`). Observe all outputs on the rising clock edge
following deassertion.

| Condition     | `main_green` | `main_yellow` | `main_red` | `side_green` | `side_yellow` | `side_red` | `ped_green` | `ped_red` | Measured | Pass/Fail |
|---------------|---|---|---|---|---|---|---|---|---|---|
| During reset  | 0 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | | |
| After release | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | | |

**Pass criterion:** Within one clock cycle after `rst_n` goes high,
`main_green = 1` and all other outputs match the table above.

---

## Test 2: Normal State Sequence (No Pedestrian Request)

**Purpose:** Verify REQ-02 and REQ-06 — the FSM cycles through
S0→S1→S2→S3→S0 without entering S4, and a yellow phase precedes every
red transition.

**Procedure:** After reset, hold `ped_req = 0`. Observe the output sequence
over one complete cycle using a logic analyser.

### Phase durations at 12 MHz

| State | Phase            | Duration |
|-------|------------------|----------|
| S0    | Main road green  | 10 s     |
| S1    | Main road yellow | 2 s      |
| S2    | Side road green  | 5 s      |
| S3    | Side road yellow | 2 s      |

### Expected output per state

| State | `main_green` | `main_yellow` | `main_red` | `side_green` | `side_yellow` | `side_red` | `ped_green` | `ped_red` | Measured | Pass/Fail |
|-------|---|---|---|---|---|---|---|---|---|---|
| S0    | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | | |
| S1    | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 1 | | |
| S2    | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | | |
| S3    | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 1 | | |

**Pass criterion:** The FSM visits all four states in the order
S0→S1→S2→S3→S0. S4 is never entered. `main_yellow = 1` is observed for the
full 2 s duration immediately before `main_red` becomes active. Likewise
`side_yellow = 1` is observed for 2 s immediately before `side_red` becomes
active.

---

## Test 3: Pedestrian Request Sequence

**Purpose:** Verify REQ-03 and REQ-09 — when `ped_req` is asserted during S0,
the FSM inserts S4 between S1 and S2. The request must be correctly latched
even if `ped_req` is deasserted before S1 is reached.

**Procedure:** After reset, assert `ped_req = 1` for approximately 100 ms
during S0 (well within the 10 s green phase), then deassert `ped_req = 0`.
Verify that the FSM enters S4 after S1 despite `ped_req` being low.

### Phase durations including pedestrian phase

| State | Phase              | Duration |
|-------|--------------------|----------|
| S0    | Main road green    | 10 s     |
| S1    | Main road yellow   | 2 s      |
| S4    | Pedestrian green   | 3 s      |
| S2    | Side road green    | 5 s      |
| S3    | Side road yellow   | 2 s      |

### Expected output per state

| State | `main_green` | `main_yellow` | `main_red` | `side_green` | `side_yellow` | `side_red` | `ped_green` | `ped_red` | Measured | Pass/Fail |
|-------|---|---|---|---|---|---|---|---|---|---|
| S0    | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | | |
| S1    | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 1 | | |
| S4    | 0 | 0 | 1 | 0 | 0 | 1 | 1 | 0 | | |
| S2    | 0 | 0 | 1 | 1 | 0 | 0 | 0 | 1 | | |
| S3    | 0 | 0 | 1 | 0 | 1 | 0 | 0 | 1 | | |
| S0    | 1 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | | |

**Pass criterion:** The FSM follows the sequence S0→S1→S4→S2→S3→S0.
S4 is entered even if `ped_req` was deasserted before S1. During S4,
`ped_green = 1` and `main_red = side_red = 1` for the full 3 s duration.

---

## Test 4: Mutual Exclusion

**Purpose:** Verify REQ-04 and REQ-05 — no two conflicting lights are ever
active simultaneously.

**Procedure:** During Tests 2 and 3, configure the logic analyser to
continuously evaluate the following conditions on every captured clock edge.

| Condition                  | Expression                  | Required value |
|----------------------------|-----------------------------|----------------|
| Car light mutual exclusion | `main_green AND side_green` | Always 0       |
| Pedestrian vs. main road   | `ped_green AND main_green`  | Always 0       |
| Pedestrian vs. side road   | `ped_green AND side_green`  | Always 0       |

**Pass criterion:** None of the above expressions are ever logic high at any
point during the entire test duration, including all state transitions.

---

## Overall Pass Criterion

The silicon test is considered passed if all four individual tests return a
Pass result. A single failure in any test constitutes an overall Fail.

| Test        | Description             | Result |
|-------------|-------------------------|--------|
| Test 1      | Reset behaviour         |        |
| Test 2      | Normal state sequence   |        |
| Test 3      | Pedestrian request path |        |
| Test 4      | Mutual exclusion        |        |
| **Overall** |                         |        |
