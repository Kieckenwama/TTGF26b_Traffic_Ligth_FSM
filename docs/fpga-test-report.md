# FPGA Test Report: Traffic Light Controller

## Test Setup

**Board:** iCEbreaker (Lattice iCE40UP5K, package sg48)  
**Bitstream:** `test/fpga/build/traffic_light.bin`  
**Clock frequency:** 12 MHz (onboard oscillator)  
**Date:** 16.06.2026  
**Tester:** Eric Kiecksee  

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
| During reset  | rot           | 1    | 0    | 0    | 0    | 1    | —     | wie erwartet | PASS |
| After release | grün          | 1    | 0    | 0    | 0    | 1    | **0** | wie erwartet | PASS |

**Pass criterion:** Nach Loslassen von BTN_N leuchtet die RGB-LED grün,
LED1 und LED5 leuchten, alle anderen LEDs aus. 7-Segment zeigt **0**.

**Observations:** Nach Loslassen von BTN_N wechselte die RGB-LED sofort auf
grün, 7-Segment zeigte 0. Verhalten entsprach exakt der Spezifikation.

**Result:** PASS

---

## Test 2: Normal State Sequence (No Pedestrian Request)

**Procedure:** Nach Reset BTN1 nicht drücken (ped_req = 0).
Zustandssequenz über einen vollständigen Zyklus beobachten.
Die 7-Segment-Anzeige zeigt dabei kontinuierlich den aktuellen State.

| State | RGB LED | LED1 | LED2 | LED3 | LED4 | LED5 | 7-Seg | Duration | Measured | Pass/Fail |
|-------|---------|------|------|------|------|------|-------|----------|----------|-----------|
| S0    | grün    | 1    | 0    | 0    | 0    | 1    | **0** | 10 s | wie erwartet | PASS |
| S1    | blau    | 1    | 0    | 0    | 0    | 1    | **1** |  2 s | wie erwartet | PASS |
| S2    | rot     | 0    | 0    | 0    | 1    | 1    | **2** |  5 s | wie erwartet | PASS |
| S3    | rot     | 0    | 1    | 0    | 0    | 1    | **3** |  2 s | wie erwartet | PASS |

**Pass criterion:** S4 wird nie eingetreten (7-Segment zeigt nie **4**).
Sequenz S0→S1→S2→S3→S0 wiederholt sich. Kein **E** erscheint.

**Observations:** Die FSM durchlief ohne Fußgängeranforderung korrekt die
Sequenz S0→S1→S2→S3→S0 in dauerhafter Wiederholung. S4 wurde zu keinem
Zeitpunkt eingenommen. Die gemessenen Phasenzeiten entsprachen den
spezifizierten Werten (10 s / 2 s / 5 s / 2 s).

**Result:** PASS

---

## Test 3: Pedestrian Request Sequence

**Procedure:** Nach Reset BTN1 für ca. 100 ms während S0 drücken
(7-Segment zeigt **0**), dann loslassen. Beobachten ob S4 nach S1
eingetreten wird (7-Segment wechselt von **1** auf **4**).

| State | RGB LED | LED1 | LED2 | LED3 | LED4 | LED5 | 7-Seg | Duration | Measured | Pass/Fail |
|-------|---------|------|------|------|------|------|-------|----------|----------|-----------|
| S0    | grün    | 1    | 0    | 0    | 0    | 1    | **0** | 10 s | wie erwartet | PASS |
| S1    | blau    | 1    | 0    | 0    | 0    | 1    | **1** |  2 s | wie erwartet | PASS |
| S4    | rot     | 1    | 0    | 1    | 0    | 0    | **4** |  3 s | wie erwartet | PASS |
| S2    | rot     | 0    | 0    | 0    | 1    | 1    | **2** |  5 s | wie erwartet | PASS |
| S3    | rot     | 0    | 1    | 0    | 0    | 1    | **3** |  2 s | wie erwartet | PASS |
| S0    | grün    | 1    | 0    | 0    | 0    | 1    | **0** | 10 s | wie erwartet | PASS |

**Pass criterion:** 7-Segment wechselt die Sequenz **0→1→4→2→3→0**.
In S4 leuchtet LED3 (ped_green) und 7-Segment zeigt **4**.
BTN1 war bereits vor S1 losgelassen.

**Observations:** Nach kurzem Drücken von BTN1 während S0 wechselte die
FSM nach S1 korrekt direkt in S4 (7-Segment 1→4), obwohl BTN1 bereits vor
Erreichen von S1 wieder losgelassen wurde. Dies bestätigt die korrekte
Latch-Funktion der Fußgängeranforderung (REQ-09). Anschließend lief die
Sequenz S4→S2→S3→S0 wie spezifiziert weiter.

**Result:** PASS

---

## Test 4: Mutual Exclusion

**Procedure:** Während Tests 2 und 3 visuell prüfen. Die 7-Segment-
Anzeige darf zu keinem Zeitpunkt **E** zeigen — das würde eine
ungültige Signalkombination und damit einen FSM-Fehler anzeigen.

| Condition                              | Required         | Observed | Pass/Fail |
|----------------------------------------|------------------|----------|-----------|
| 7-Segment zeigt nie **E**              | immer gültig     | nie E aufgetreten | PASS |
| RGB grün + LED4 (side_green)           | nie gleichzeitig | nie gleichzeitig | PASS |
| RGB grün + LED3 (ped_green)            | nie gleichzeitig | nie gleichzeitig | PASS |
| LED3 (ped_green) + LED4 (side_green)   | nie gleichzeitig | nie gleichzeitig | PASS |

**Pass criterion:** Die 7-Segment-Anzeige zeigt ausschließlich die
Ziffern 0–4 und niemals **E**.

**Observations:** Während der gesamten Beobachtungsdauer über mehrere
vollständige Zyklen (mit und ohne Fußgängeranforderung) zeigte die
7-Segment-Anzeige ausschließlich gültige Ziffern (0–4). Kein Fehlerzustand
(E) wurde beobachtet, was die korrekte gegenseitige Ausschließung aller
Lichtkombinationen bestätigt.

**Result:** PASS

---

## Overall Result

| Test        | Description             | Result  |
|-------------|--------------------------|---------|
| Test 1      | Reset behaviour          | PASS    |
| Test 2      | Normal state sequence    | PASS    |
| Test 3      | Pedestrian request path  | PASS    |
| Test 4      | Mutual exclusion         | PASS    |
| **Overall** |                          | **PASS** |

**Summary:** Das auf den iCEbreaker FPGA geflashte Design verhielt sich in
allen vier Testfällen wie spezifiziert. Reset-Verhalten, normale
Zustandssequenz, Fußgänger-Latch-Mechanismus und gegenseitige
Ausschließung aller Lichtkombinationen wurden erfolgreich verifiziert.
Die gemessenen Phasenzeiten entsprachen den spezifizierten Werten.
Das Design ist bereit für die Einreichung zum Tiny Tapeout Shuttle.



https://github.com/user-attachments/assets/b1a28d9f-6eaa-4f43-85a0-f08cc5fb954c



