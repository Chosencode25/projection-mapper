# Native USB-DMX moving-head reference

Source: user-supplied photos of the fixture and its manual, November 8, 2026. The fixture has 3-pin DMX IN and OUT. The fixture model and USB adapter protocol are unidentified. The channel map below is transcribed from the manual and awaits a hardware check.

## Fixture patch

The fixture menu shows DMX start address under `A001` (001–512) and channel mode under `Chnd` (`CH 9` or `CH 11`). Match both in the app. The channel numbers below are relative to the start address, so relative channel 1 is the start address itself. The whole patch must fit within 512 slots.

| Function | CH 9 | CH 11 | DMX values |
|---|---:|---:|---|
| Pan | 1 | 1 | 0–255 |
| Pan fine | | 2 | 0–255 |
| Tilt | 2 | 3 | 0–255 |
| Tilt fine | | 4 | 0–255 |
| Color wheel | 3 | 5 | See below |
| Gobo wheel | 4 | 6 | See below |
| Strobe | 5 | 7 | 0–9 nonfunctional, 10–249 slow to fast, 250–255 off |
| Dimmer | 6 | 8 | 0–9 off, 10–255 dark to bright |
| Pan/tilt speed | 7 | 9 | 0–255 fast to slow |
| Auto/sound | 8 | 10 | 0–59 leaves control to the other channels. 60–159 selects auto programs. 160–255 selects sound programs. |
| Reset | 9 | 11 | 0–249 inactive, 250–255 reset |

Color wheel ranges in steps of 10 from 0–9 through 130–139: open white, red, green, blue, yellow, orange, light blue, pink, light blue + pink, orange + light blue, blue + yellow, green + blue, red + green. 140–255 cycles colors from slow to fast.

Gobo ranges in steps of 8 from 0–7 through 56–63: open, then gobos 1–7. The same order repeats at 64–127 for shake. 128–255 cycles gobos from slow to fast.

## Proposed first hardware check

- Identify the adapter from its label, the output interface reported by Lightkey, or the Mac's USB inventory. USB identification alone may be inconclusive for generic adapters. The fixture chart describes the DMX side and does not identify the USB protocol.
- Start with CH 9 at address 001. Connect the adapter's DMX output to the fixture's DMX IN. Match the configured address and mode before enabling output.
- Start with dimmer 0, strobe 255, auto/sound 0 and reset 0. Test small pan and tilt changes with the beam dark, then bring up a low intensity and test color, gobo and blackout. Keep strobe, reset and auto/sound programs outside the first cue controls.
- Use the projection timeline as the clock for two fixed looks and a blackout. Check seek, loop and stop on the fixture, and measure movement lead time by observing when the beam actually lands. Test unplug separately because a disconnected adapter cannot deliver a blackout command.
- Test CH 11 fine pan and tilt separately before marking that mode hardware verified.
