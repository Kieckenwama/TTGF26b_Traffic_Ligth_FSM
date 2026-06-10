# FPGA Test Report: Traffic Light Controller

## Test Setup

**Board:** iCEbreaker (Lattice iCE40UP5K, package sg48)  
**Bitstream:** `test/fpga/fpga_top/fpga_top.bin`  
**Clock frequency:** 12 MHz (onboard oscillator)  
**Date:** <!-- date of test -->  
**Tester:** <!-- name -->  

---

## LED-Belegung

### Hauptstraße — onboard RGB LED

Die onboard RGB-LED zeigt den aktuellen Zustand der Hauptstraße.
Die LEDs sind aktiv-low und werden in `fpga_top.v` invertiert.

| LED | Pin | Signal | Leuchtet in State |
|-----|-----|--------|-------------------|
| LEDG_N (grün) | 37 | `main_green`  | S0 |
| LED_BLU_N (blau) | 41 | `main_yellow` | S1 |
| LEDR_N (rot) | 11 | `main_red`    | S2, S3, S4 |

### Nebenstraße — PMOD2 LEDs

| LED | Pin | Signal | Leuchtet in State |
|-----|-----|--------|-------------------|
| LED1 | 26 | `side_red`    | S0, S1, S4 |
| LED2 | 27 | `side_yellow` | S3 |
| LED4 | 23 | `side_green`  | S2 |

### Fußgänger — PMOD2 LEDs

| LED | Pin | Signal | Leuchtet in State |
|-----|-----|--------|-------------------|
| LED3 | 25 | `ped_green` | S4 |
| LED5 | 21 | `ped_red`   | S0, S1, S2, S3 |

### 7-Segment Anzeige — State-Anzeige

Die 7-Segment-Anzeige (Ziffer 1, PMOD1A+1B) zeigt den aktuellen
FSM-State als Ziffer 0–4. Da `top.v` keinen `state`-Port nach außen
führt, wird der State in `fpga_top.v` aus den LED-Ausgangssignalen
eindeutig rückgeschlossen:

| Angezeigte Ziffer | State | Bedeutung              | Aktive Signale                    |
|-------------------|-------|------------------------|-----------------------------------|
| **0**             | S0    | Hauptstraße grün       | `main_green`, `side_red`, `ped_red` |
| **1**             | S1    | Hauptstraße gelb       | `main_yellow`, `side_red`, `ped_red` |
| **2**             | S2    | Nebenstraße grün       | `main_red`, `side_green`, `ped_red` |
| **3**             | S3    | Nebenstraße gelb       | `main_red`, `side_yellow`, `ped_red` |
| **4**             | S4    | Fußgänger grün         | `main_red`, `side_red`, `ped_green` |
| **E**             | —     | Ungültige Kombination  | Fehler in der FSM                 |

Die 7-Segment-Anzeige ermöglicht eine schnelle Verifikation des
FSM-Zustands unabhängig von den einzelnen LEDs und ergänzt damit
die visuelle Überprüfung der Ampellichter.

---

## Test 1: Reset Behaviour

**Procedure:** BTN_N gedrückt halten (rst_n = 0), dann loslassen.
Auf der nächsten steigenden Taktflanke nach Loslassen prüfen.

| Condition     | RGB LED       | LED1 | LED2 | LED3 | LED4 | LED5 | 7-Seg | Measured | Pass/Fail |
|---------------|---------------|------|------|------|------|------|-------|----------|-----------|
| During reset  | rot           | 1    | 0    | 0    | 0    | 1    | —     | <!-- --> | |
| After release | grün          | 1    | 0    | 0    | 0    | 1    | **0** | <!-- --> | |

**Pass criterion:** Nach Loslassen von BTN_N leuchtet die RGB-LED grün,
LED1 und LED5 leuchten, alle anderen LEDs aus. 7-Segment zeigt **0**.

**Observations:** <!-- describe what was observed -->

**Result:** <!-- PASS / FAIL -->

---

## Test 2: Normal State Sequence (No Pedestrian Request)

**Procedure:** Nach Reset BTN1 nicht drücken (ped_req = 0).
Zustandssequenz über einen vollständigen Zyklus beobachten.
Die 7-Segment-Anzeige zeigt dabei kontinuierlich den aktuellen State.

| State | RGB LED | LED1 | LED2 | LED3 | LED4 | LED5 | 7-Seg | Duration | Measured | Pass/Fail |
|-------|---------|------|------|------|------|------|-------|----------|----------|-----------|
| S0    | grün    | 1    | 0    | 0    | 0    | 1    | **0** | 10 s | <!-- --> | |
| S1    | blau    | 1    | 0    | 0    | 0    | 1    | **1** |  2 s | <!-- --> | |
| S2    | rot     | 0    | 0    | 0    | 1    | 1    | **2** |  5 s | <!-- --> | |
| S3    | rot     | 0    | 1    | 0    | 0    | 1    | **3** |  2 s | <!-- --> | |

**Pass criterion:** S4 wird nie eingetreten (7-Segment zeigt nie **4**).
Sequenz S0→S1→S2→S3→S0 wiederholt sich. Kein **E** erscheint.

**Observations:** <!-- describe what was observed -->

**Result:** <!-- PASS / FAIL -->

---

## Test 3: Pedestrian Request Sequence

**Procedure:** Nach Reset BTN1 für ca. 100 ms während S0 drücken
(7-Segment zeigt **0**), dann loslassen. Beobachten ob S4 nach S1
eingetreten wird (7-Segment wechselt von **1** auf **4**).

| State | RGB LED | LED1 | LED2 | LED3 | LED4 | LED5 | 7-Seg | Duration | Measured | Pass/Fail |
|-------|---------|------|------|------|------|------|-------|----------|----------|-----------|
| S0    | grün    | 1    | 0    | 0    | 0    | 1    | **0** | 10 s | <!-- --> | |
| S1    | blau    | 1    | 0    | 0    | 0    | 1    | **1** |  2 s | <!-- --> | |
| S4    | rot     | 1    | 0    | 1    | 0    | 0    | **4** |  3 s | <!-- --> | |
| S2    | rot     | 0    | 0    | 0    | 1    | 1    | **2** |  5 s | <!-- --> | |
| S3    | rot     | 0    | 1    | 0    | 0    | 1    | **3** |  2 s | <!-- --> | |
| S0    | grün    | 1    | 0    | 0    | 0    | 1    | **0** | 10 s | <!-- --> | |

**Pass criterion:** 7-Segment wechselt die Sequenz **0→1→4→2→3→0**.
In S4 leuchtet LED3 (ped_green) und 7-Segment zeigt **4**.
BTN1 war bereits vor S1 losgelassen.

**Observations:** <!-- describe what was observed -->

**Result:** <!-- PASS / FAIL -->

---

## Test 4: Mutual Exclusion

**Procedure:** Während Tests 2 und 3 visuell prüfen. Die 7-Segment-
Anzeige darf zu keinem Zeitpunkt **E** zeigen — das würde eine
ungültige Signalkombination und damit einen FSM-Fehler anzeigen.

| Condition                              | Required         | Observed | Pass/Fail |
|----------------------------------------|------------------|----------|-----------|
| 7-Segment zeigt nie **E**              | immer gültig     | <!-- --> | |
| RGB grün + LED4 (side_green)           | nie gleichzeitig | <!-- --> | |
| RGB grün + LED3 (ped_green)            | nie gleichzeitig | <!-- --> | |
| LED3 (ped_green) + LED4 (side_green)   | nie gleichzeitig | <!-- --> | |

**Pass criterion:** Die 7-Segment-Anzeige zeigt ausschließlich die
Ziffern 0–4 und niemals **E**.

**Observations:** <!-- describe what was observed -->

**Result:** <!-- PASS / FAIL -->

---

## Overall Result

| Test        | Description             | Result             |
|-------------|-------------------------|--------------------|
| Test 1      | Reset behaviour         | <!-- PASS/FAIL --> |
| Test 2      | Normal state sequence   | <!-- PASS/FAIL --> |
| Test 3      | Pedestrian request path | <!-- PASS/FAIL --> |
| Test 4      | Mutual exclusion        | <!-- PASS/FAIL --> |
| **Overall** |                         | <!-- PASS/FAIL --> |

**Summary:** <!-- brief description of overall FPGA test outcome -->
