# cocotb Testbench: Traffic Light Controller
# Tests: VAL-02, VAL-03, VAL-07, VAL-08, VAL-09
#
# DUT is top, which wraps Traffic_Light + timer 

# RTL simulation: state read from internal register, timer count checked
# GL  simulation: state reconstructed from uo_out LED signals,
#                 timer count check skipped (internal signals not accessible)
 
import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

# ----------------------------------------------------------------
# Phase durations — must match localparams in tb_top.v exactly
# ----------------------------------------------------------------
MAIN_GREEN_TIME  = 5
MAIN_YELLOW_TIME = 3
SIDE_GREEN_TIME  = 4
SIDE_YELLOW_TIME = 3
PED_GREEN_TIME   = 4

# State encoding — must match Traffic_Light.v localparams
S0, S1, S2, S3, S4 = 0, 1, 2, 3, 4
STATE_NAMES = {S0: "S0", S1: "S1", S2: "S2", S3: "S3", S4: "S4"}

# ----------------------------------------------------------------
# Helper: apply reset
# ----------------------------------------------------------------
async def do_reset(dut):
    dut.rst_n.value  = 0
    dut.ui_in.value  = 0
    dut.ena.value    = 1
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value  = 1
    await RisingEdge(dut.clk)
    dut.rst_n.value   = 0
    dut.ped_req.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ----------------------------------------------------------------
# Helper: get FSM state
# RTL: reads internal state register directly via hierarchy
# GL:  reconstructs state from uo_out LED outputs
#      uo_out bit mapping (from info.yaml pinout):
#        [0] main_green  [1] main_yellow  [2] main_red
#        [3] side_green  [4] side_yellow  [5] side_red
#        [6] ped_green   [7] ped_red

# ----------------------------------------------------------------
def get_state(dut):
    if os.environ.get("GATES") == "yes":
        # GL simulation: reconstruct from output signals
        uo = int(dut.uo_out.value)
        main_green  = (uo >> 0) & 1
        main_yellow = (uo >> 1) & 1
        side_green  = (uo >> 3) & 1
        side_yellow = (uo >> 4) & 1
        ped_green   = (uo >> 6) & 1
 
        if   main_green  == 1: return S0
        elif main_yellow == 1: return S1
        elif side_green  == 1: return S2
        elif side_yellow == 1: return S3
        elif ped_green   == 1: return S4
        else:                  return -1  # ungültige Kombination
    else:
        # RTL simulation: read internal state register
        return int(dut.user_project.top.u_Traffic_Light.state.value)

# ----------------------------------------------------------------
# Helper: wait until FSM reaches target state (with timeout)
# ----------------------------------------------------------------
async def wait_for_state(dut, target, timeout=300):
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if get_state(dut) == target:
            return
    raise AssertionError(
        f"Timeout: state {STATE_NAMES[target]} not reached within {timeout} cycles"
    )

# ----------------------------------------------------------------
# Helper: wait until FSM FRESHLY enters target state
# ----------------------------------------------------------------
async def wait_for_fresh_state(dut, target, timeout=300):
    prev = get_state(dut)
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        cur = get_state(dut)
        if cur == target and prev != target:
            return
        prev = cur
    raise AssertionError(
        f"Timeout: fresh entry into {STATE_NAMES[target]} not seen within {timeout} cycles"
    )

# ----------------------------------------------------------------
# Helper: set ped_req via ui_in[0]
# ----------------------------------------------------------------
def set_ped_req(dut, val):
    dut.ui_in.value = int(val) & 0x01

# ================================================================
# VAL-02: State sequence without pedestrian request
# Expected order: S0 -> S1 -> S2 -> S3 -> S0 (twice), S4 never
# ================================================================
@cocotb.test()
async def val02_sequence_no_ped(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    dut._log.info("VAL-02: State sequence without pedestrian request")

    expected = [S0, S1, S2, S3, S0, S1, S2, S3, S0]
    visited  = []
    last     = -1

    for _ in range(500):
        await RisingEdge(dut.clk)
        cur = get_state(dut)

        assert cur != S4, "VAL-02 FAIL: S4 entered without pedestrian request"

        if cur != last:
            visited.append(cur)
            last = cur

        if len(visited) >= len(expected):
            break

    assert visited == expected, \
        f"VAL-02 FAIL: got {[STATE_NAMES[s] for s in visited]}, " \
        f"expected {[STATE_NAMES[s] for s in expected]}"

    dut._log.info(f"VAL-02 PASS: {[STATE_NAMES[s] for s in visited]}")


# ================================================================
# VAL-03: State sequence with pedestrian request
# Assert ped_req during S0, expect S0->S1->S4->S2->S3->S0
# ================================================================
@cocotb.test()
async def val03_sequence_with_ped(dut):
    cocotb.start_soon(Clock(dut.clk, 84, unit="ns").start()) # 12 MHz clock
    await do_reset(dut)

    dut._log.info("VAL-03: State sequence with pedestrian request")

    # Warte auf S0, dann ped_req für 2 Takte assertieren
    await wait_for_state(dut, S0)
    dut.ped_req.value = 1
    await ClockCycles(dut.clk, 2)
    dut.ped_req.value = 0

    # Sequenz verfolgen bis S0 nach S3 wieder erreicht wird
    visited = [get_state(dut)]
    last    = visited[0]

    for _ in range(500):
        await RisingEdge(dut.clk)
        cur = get_state(dut)
        if cur != last:
            visited.append(cur)
            last = cur
        if len(visited) >= 2 and visited[-1] == S0 and S3 in visited:
            break

    expected = [S0, S1, S4, S2, S3, S0]
    assert visited == expected, \
        f"VAL-03 FAIL: got {[STATE_NAMES[s] for s in visited]}, " \
        f"expected {[STATE_NAMES[s] for s in expected]}"

    dut._log.info(f"VAL-03 PASS: {[STATE_NAMES[s] for s in visited]}")


# ================================================================
# VAL-07: Phase durations match localparam values
# Misst die tatsächliche Anzahl Takte in jedem State.
#
# Timing-Erklärung:
#   Der Timer zählt von 0 bis duration (inklusiv), dann ist done=1.
#   Der State bleibt noch einen Takt aktiv während done=1 gilt,
#   bevor die Transition auf der nächsten Flanke stattfindet.
#   Daher ist die sichtbare Dauer = duration + 1 Takte.
#   tb_top.v kompensiert das: MAIN_GREEN_TIME=4 → sichtbar 5 Takte.
#   wait_for_fresh_state stellt sicher dass die Messung am
#   ersten Takt des neuen States beginnt.
# ================================================================
@cocotb.test()
async def val07_phase_durations(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    dut._log.info("VAL-07: Measuring phase durations")

    expected = {
        S0: MAIN_GREEN_TIME,
        S1: MAIN_YELLOW_TIME,
        S2: SIDE_GREEN_TIME,
        S3: SIDE_YELLOW_TIME,
    }

    # Einen kompletten Zyklus durchlaufen lassen (S0->S1->S2->S3->S0)
    # damit wir bei einem sauberen S0-Start ankommen
    await wait_for_state(dut, S0)   # irgendwo in S0
    await wait_for_state(dut, S3)   # S3 abwarten
    await wait_for_state(dut, S0)   # jetzt beginnt S0 frisch nach S3

    # Jetzt jeden State von Anfang an messen
    for target, exp_dur in expected.items():
        # Wir sind am ersten Takt von target
        count = 1
        while get_state(dut) == target:
            await RisingEdge(dut.clk)
            count += 1
            if count > exp_dur + 10:
                break

        assert count == exp_dur + 3, \
            f"VAL-07 FAIL: {STATE_NAMES[target]} lasted {count} cycles, " \
            f"expected {exp_dur + 3}"
        dut._log.info(f"  {STATE_NAMES[target]}: {count} cycles OK")

    dut._log.info("VAL-07 PASS: all phase durations correct")


# ================================================================
# VAL-08: Timer resets to zero on every state transition
# Liest u_timer.count direkt — muss 0 sein einen Takt nach Transition
# ================================================================
@cocotb.test()
async def val08_timer_reset_on_transition(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    dut._log.info("VAL-08: Timer reset on state transition")

    gl_mode    = os.environ.get("GATES") == "yes"
    transitions = 0
    last_state  = get_state(dut)

    for _ in range(500):
        await RisingEdge(dut.clk)
        cur = get_state(dut)

        if cur != last_state:
            # Transition erkannt — load=1 in diesem Takt
            # Einen weiteren Takt warten → count muss dann 0 sein
            prev       = last_state
            last_state = cur
            await RisingEdge(dut.clk)

            
            if gl_mode:
                # GL: cannot access internal signals — log transition only
                dut._log.info(
                    f"  {STATE_NAMES[prev]}->{STATE_NAMES[cur]}: "
                    f"GL mode, timer count check skipped"
                )
            else:
                count = int(dut.user_project.top.u_timer.count.value)
                assert count == 0, \
                    f"VAL-08 FAIL: timer count={count} after " \
                    f"{STATE_NAMES[prev]}->{STATE_NAMES[cur]}, expected 0"
                dut._log.info(
                    f"  {STATE_NAMES[prev]}->{STATE_NAMES[cur]}: count={count} OK"
                )
            transitions += 1

        if transitions >= 5:
            break

    assert transitions >= 5, \
        f"VAL-08 FAIL: only {transitions} transitions observed"

    dut._log.info("VAL-08 PASS: timer resets correctly on every transition")


# ================================================================
# VAL-09: Pedestrian request latching
# ped_req nur EINEN Takt pulsieren in S0, dann deassertieren.
# FSM muss trotzdem S4 betreten.
# ================================================================
@cocotb.test()
async def val09_ped_req_latching(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await do_reset(dut)

    dut._log.info("VAL-09: Pedestrian request latching")

    # Warte auf S0, ped_req genau einen Takt pulsieren
    await wait_for_state(dut, S0)
    dut.ped_req.value = 1
    await RisingEdge(dut.clk)
    dut.ped_req.value = 0

    # Sicherstellen dass ped_req weg ist bevor S1 erreicht wird
    await wait_for_state(dut, S1)
    assert int(dut.ped_req.value) == 0, \
        "VAL-09: ped_req still high in S1 — test setup error"

    # Trotz deassertiertem ped_req muss FSM S4 betreten
    s4_reached = False
    for _ in range(200):
        await RisingEdge(dut.clk)
        cur = get_state(dut)
        if cur == S4:
            s4_reached = True
            break
        if cur == S2:
            break

    assert s4_reached, \
        "VAL-09 FAIL: FSM skipped S4 — pedestrian request was not latched"

    dut._log.info("VAL-09 PASS: pedestrian request correctly latched")