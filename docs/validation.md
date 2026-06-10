# Validation: Traffic Light FSM

## VAL-01: Reset state
[REQ-01](specification.md#req-01-reset-state)

Apply rst_n = 0 for one clock cycle, then rst_n = 1.
Verify that within one clock cycle after deassertion of rst_n,
the outputs main_green = 1, side_red = 1, ped_red = 1 are observed
and all other light outputs are logic low.

## VAL-02: State sequence without pedestrian request
[REQ-02](specification.md#req-02-state-sequence-without-pedestrian-request)

With ped_req = 0 held constant, apply reset and observe the output
sequence over five complete cycles. Verify that the order
S0 → S1 → S2 → S3 → S0 is maintained in every cycle without deviation.

## VAL-03: State sequence with pedestrian request
[REQ-03](specification.md#req-03-state-sequence-with-pedestrian-request)

Assert ped_req = 1 during state S0. Verify that the FSM follows
the order S0 → S1 → S4 → S2 → S3 → S0, and that S4 is entered
before S2 in that cycle.

## VAL-04: Mutual exclusion — car lights
[REQ-04](specification.md#req-04-mutual-exclusion--car-lights)

Simulate the FSM for at least three full cycles including a
pedestrian phase. At every clock cycle, verify that the condition
(main_green AND side_green) = 0 holds without exception.

## VAL-05: Mutual exclusion — pedestrian safety
[REQ-05](specification.md#req-05-mutual-exclusion--pedestrian-safety)

Simulate the FSM for at least three full cycles including a
pedestrian phase. At every clock cycle, verify that both conditions
(ped_green AND main_green) = 0 and (ped_green AND side_green) = 0
hold without exception.

## VAL-06: Yellow phase before red
[REQ-06](specification.md#req-06-yellow-phase-before-red)

Observe all transitions to a red state. Verify that main_yellow = 1
is asserted for exactly MAIN_YELLOW_TIME clock cycles immediately
before main_red is asserted, and that side_yellow = 1 is asserted
for exactly SIDE_YELLOW_TIME clock cycles immediately before
side_red is asserted.

## VAL-07: Phase duration configurable via localparam
[REQ-07](specification.md#req-07-phase-duration--configurable-via-localparam)

Instantiate the design twice with different values for all five
localparam constants. Measure the number of clock cycles spent in
each state and verify that the measured duration equals the
configured localparam value in both instantiations.

## VAL-08: Timer reset on state transition
[REQ-08](specification.md#req-08-timer-reset-on-state-transition)

At each state transition, verify that the internal timer output
reads zero in the same clock cycle in which the new state is entered.

## VAL-09: Pedestrian request latching
[REQ-09](specification.md#req-09-pedestrian-request-latching)

Assert ped_req = 1 for exactly one clock cycle during state S0,
then deassert it (ped_req = 0) before S1 is reached. Verify that
the FSM nonetheless enters S4 in that cycle, confirming that the
request was latched correctly.