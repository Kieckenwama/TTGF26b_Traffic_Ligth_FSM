# Specification: Traffic Light FSM

## REQ-01: Reset state
After reset (rst_n = 0 for at least one clock cycle), the FSM 
shall enter state S0 (main road green, side road red, 
pedestrians red) within one clock cycle.

[Verification](verification-report.md#val-01-reset-state)

## REQ-02: State sequence without pedestrian request
Without a pending pedestrian request, the FSM shall cycle 
through states in the fixed order:
S0 → S1 → S2 → S3 → S0

[Verification](verification-report.md#val-02-state-sequence-without-pedestrian-request)

## REQ-03: State sequence with pedestrian request
If ped_req_latch = 1 is aktive during state S1, the FSM shall 
transition to state S4 (pedestrian green) before S2, 
resulting in the order:
S0 → S1 → S4 → S2 → S3 → S0

[Verification](verification-report.md#val-03-state-sequence-with-pedestrian-request)

## REQ-04: Mutual exclusion — car lights
At no point in time shall main_green and side_green both be 
logic high simultaneously.

[Verification](verification-report.md#val-04-mutual-exclusion--car-lights)

## REQ-05: Mutual exclusion — pedestrian safety
At no point in time shall ped_green and either main_green or 
side_green be logic high simultaneously.

[Verification](verification-report.md#val-05-mutual-exclusion--pedestrian-safety)

## REQ-06: Yellow phase before red
The FSM shall assert a yellow output for the active road 
before every transition to red. Yellow phases occur in 
states S1 (main road) and S3 (side road).

[Verification](verification-report.md#val-06-yellow-phase-before-red)

## REQ-07: Phase duration — configurable via localparam
Each phase duration shall be individually configurable 
via localparam constants:
- MAIN_GREEN_TIME  : duration of S0 in clock cycles
- MAIN_YELLOW_TIME : duration of S1 in clock cycles
- SIDE_GREEN_TIME  : duration of S2 in clock cycles
- PED_GREEN_TIME   : duration of S4 in clock cycles
- SIDE_YELLOW_TIME : duration of S3 in clock cycles

[Verification](verification-report.md#val-07-phase-duration-configurable-via-localparam)

## REQ-08: Timer reset on state transition
The internal timer shall reset to zero on every state 
transition, within the same clock cycle as the transition.

[Verification](verification-report.md#val-08-timer-reset-on-state-transition)

## REQ-09: Pedestrian request latching
If ped_req is asserted at any point during S0 or S1 or S2 or S3, 
the request shall be latched and honored in the subsequent S1 state.

[Verification](verification-report.md#val-09-pedestrian-request-latching)
