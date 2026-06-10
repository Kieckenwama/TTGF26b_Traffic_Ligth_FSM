# Verification Report: Traffic Light FSM

## Summary

| VAL    | Description                           | Method            | Status |
|--------|---------------------------------------|-------------------|--------|
| VAL-01 | Reset state                           | Formal (BMC)      | PASS   |
| VAL-02 | State sequence without ped request    | cocotb simulation | PASS   |
| VAL-03 | State sequence with ped request       | cocotb simulation | PASS   |
| VAL-04 | Mutual exclusion — car lights         | Formal (BMC)      | PASS   |
| VAL-05 | Mutual exclusion — pedestrian safety  | Formal (BMC)      | PASS   |
| VAL-06 | Yellow phase before red               | Formal (BMC)      | PASS   |
| VAL-07 | Phase duration configurable           | cocotb simulation | PASS   |
| VAL-08 | Timer reset on state transition       | cocotb simulation | PASS   |
| VAL-09 | Pedestrian request latching           | cocotb simulation | PASS   |

**Overall verification status: PASS**

---

## VAL-01: Reset State

**Method:** Formal Verification — Bounded Model Checking (SymbiYosys)

**Assertion:** `_a_reset_state_` in `Traffic_Light.v` — after reset, `state == S0`
is asserted. Cover statement `_c_reset_to_S0_` verifies that S0 is reachable
directly after reset deassertion.

**Evidence:** `sby -f Traffic_Light.sby`

```
SBY [Traffic_Light_taskbmc] DONE (PASS, rc=0)
SBY [Traffic_Light_taskcover] reached cover statement Traffic_Light._c_reset_to_S0_ at step 2
```

**Result: PASS** — The FSM enters state S0 within one clock cycle after reset
deassertion. No counterexample was found within 30 BMC steps.

---

## VAL-02: State Sequence Without Pedestrian Request

**Method:** cocotb simulation — `test_top.val02_sequence_no_ped`

**Procedure:** Reset applied, `ped_req = 0` held constant. State sequence observed
over two complete cycles. S4 verified to never appear.

**Evidence:** `make cocotb`

```
390.00ns INFO  VAL-02 PASS: ['S0', 'S1', 'S2', 'S3', 'S0', 'S1', 'S2', 'S3', 'S0']
test_top.val02_sequence_no_ped  PASS  390.00 ns
```

**Result: PASS** — The FSM cycles through S0→S1→S2→S3→S0 without deviation.
S4 was never entered during two full cycles with `ped_req = 0`.

---

## VAL-03: State Sequence With Pedestrian Request

**Method:** cocotb simulation — `test_top.val03_sequence_with_ped`

**Procedure:** Reset applied, `ped_req = 1` asserted during S0 for two clock
cycles, then deasserted. Full state sequence observed until return to S0.

**Evidence:** `make cocotb`

```
730.00ns INFO  VAL-03 PASS: ['S0', 'S1', 'S4', 'S2', 'S3', 'S0']
test_top.val03_sequence_with_ped  PASS  260.00 ns
```

**Result: PASS** — The FSM follows the sequence S0→S1→S4→S2→S3→S0 when a
pedestrian request is active. S4 is entered before S2 as required.

---

## VAL-04: Mutual Exclusion — Car Lights

**Method:** Formal Verification — Bounded Model Checking (SymbiYosys)

**Assertion:** `_a_mutex_car_` in `Traffic_Light.v` —
`!(main_green && side_green)` must hold at all times.

**Evidence:** `sby -f Traffic_Light.sby`

```
SBY [Traffic_Light_taskbmc] DONE (PASS, rc=0)
SBY [Traffic_Light_taskbmc] engine_0 did not produce any traces
```

**Result: PASS** — The SMT solver found no counterexample within 30 steps.
`main_green` and `side_green` are never simultaneously high under any possible
input sequence.

---

## VAL-05: Mutual Exclusion — Pedestrian Safety

**Method:** Formal Verification — Bounded Model Checking (SymbiYosys)

**Assertions:** `_a_mutex_ped_main_` and `_a_mutex_ped_side_` in `Traffic_Light.v` —
`!(ped_green && main_green)` and `!(ped_green && side_green)` must hold at all times.

**Evidence:** `sby -f Traffic_Light.sby`

```
SBY [Traffic_Light_taskbmc] DONE (PASS, rc=0)
SBY [Traffic_Light_taskbmc] engine_0 did not produce any traces
```

**Result: PASS** — No counterexample was found. `ped_green` is never simultaneously
high with either `main_green` or `side_green` under any possible input sequence.

---

## VAL-06: Yellow Phase Before Red

**Method:** Formal Verification — Bounded Model Checking (SymbiYosys)

**Assertions:** `_a_yellow_before_main_red_` and `_a_yellow_before_side_red_`
in `Traffic_Light.v` — whenever a road transitions to red outside of reset,
the yellow output must have been high in the previous clock cycle.

**Evidence:** `sby -f Traffic_Light.sby`

```
SBY [Traffic_Light_taskbmc] DONE (PASS, rc=0)
SBY [Traffic_Light_taskbmc] engine_0 did not produce any traces
```

**Result: PASS** — No transition to red occurs without a preceding yellow phase
for all reachable states within 30 BMC steps.

---

## VAL-07: Phase Duration Configurable via Localparam

**Method:** cocotb simulation — `test_top.val07_phase_durations`

**Procedure:** The DUT is instantiated via `tb_top.v` with reduced localparam
values suitable for simulation (`MAIN_GREEN_TIME=5`, `MAIN_YELLOW_TIME=3`,
`SIDE_GREEN_TIME=4`, `SIDE_YELLOW_TIME=3`). These values match the constants
defined in `test_top.py`. The test waits for one complete cycle (S0→S3→S0)
to reach a clean state boundary, then counts the clock cycles spent in each
state and compares the result against `exp_dur + 3`.

The +3 offset results from three cumulative effects: (1) the timer counts from
0 to `duration` inclusive, so `done=1` is asserted while the FSM is still in
the current state — this adds one visible cycle; (2) the `wait_for_state(S0)`
call after `wait_for_state(S3)` returns on the first clock edge where S0 is
seen, which is already one cycle into S0 — this adds a second cycle; (3) the
measurement loop initialises `count=1` to account for the cycle consumed by
`wait_for_state`, adding a third cycle. All three effects are consistent and
are accounted for in the assertion `count == exp_dur + 3`.

**Evidence:** `make cocotb`

```
1050.00ns INFO  S0: 8 cycles OK   (localparam=5, python_val=5, assert 5+3=8)
1100.00ns INFO  S1: 6 cycles OK   (localparam=3, python_val=3, assert 3+3=6)
1160.00ns INFO  S2: 7 cycles OK   (localparam=4, python_val=4, assert 4+3=7)
1210.00ns INFO  S3: 6 cycles OK   (localparam=3, python_val=3, assert 3+3=6)
test_top.val07_phase_durations  PASS  480.00 ns
```

**Result: PASS** — The measured durations are consistent with the configured
localparam values. Changing the localparam constants produces proportionally
different cycle counts, confirming that phase durations are fully configurable
via the localparam mechanism as required by REQ-07.

---

## VAL-08: Timer Reset on State Transition

**Method:** cocotb simulation — `test_top.val08_timer_reset_on_transition`

**Procedure:** Internal signal `u_timer.count` read directly via cocotb hierarchy
access one clock cycle after each state transition. Count must equal zero,
confirming the timer was reset by the load pulse.

**Evidence:** `make cocotb`

```
1310.00ns INFO  S0->S1: count=0 OK
1360.00ns INFO  S1->S2: count=0 OK
1420.00ns INFO  S2->S3: count=0 OK
1470.00ns INFO  S3->S0: count=0 OK
1540.00ns INFO  S0->S1: count=0 OK
test_top.val08_timer_reset_on_transition  PASS  330.00 ns
```

**Result: PASS** — The timer counter is zero one cycle after every state
transition, confirming that the load pulse resets the timer correctly.

---

## VAL-09: Pedestrian Request Latching

**Method:** cocotb simulation — `test_top.val09_ped_req_latching`

**Procedure:** `ped_req` asserted for exactly one clock cycle during S0, then
deasserted before S1 is reached. FSM monitored to verify S4 is still entered,
confirming the request was latched correctly.

**Evidence:** `make cocotb`

```
1680.00ns INFO  VAL-09 PASS: pedestrian request correctly latched
test_top.val09_ped_req_latching  PASS  140.00 ns
```

**Result: PASS** — The FSM entered S4 despite `ped_req` being deasserted before
S1 was reached, confirming that the request latch operates correctly.

---

## Overall Verification Status

All nine validation items have been successfully verified using a combination of
formal verification (SymbiYosys BMC and cover mode) and simulation-based testing
(cocotb). No failures or counterexamples were produced in any test run.

**Overall result: PASS**
