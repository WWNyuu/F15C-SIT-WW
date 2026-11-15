# F-15C SIT (WW)

A SIT page for the Flaming Cliffs F-15C in DCS World, by the Wild Wolves (127th Vitezovi FAS). It puts a working tactical situation page and its menu pages on the jet's lower-left MPCD: own radar and datalink picture, threat rings, route and bullseye, missiles in flight, CMD programs, combat jettison, SRS radio presets and data cartridges, with a power-up self test and a clickable brightness knob.

**New in 1.2:** the front UHF-1 radio panel and the IFF MODE 3/A wheels under the HUD work with the mouse (channel, manual frequency, CHAN / MAN / GUARD, SRS volume, transponder code and IDENT through SRS), two exterior light knobs switch the anti-collision and navigation lights, the FLIGHT DATA page builds your flight in four slots, the SIT page has WP+ / WP-, and DTM cartridges become Route Tool presets so the jet itself flies the cartridge route.

**New in 1.1:** a JHMCS helmet display with its own cockpit panel, helmet-cued radar acquisition (helmet acquisition, long range boresight, vertical scan, supersearch) and the Eagle's HOTAS switches (weapon select, missile reject, target step, unlock), a weapon inventory line with missile models, an AIM-120 fly-out line that flashes once the missile goes active, and a printable controls guide.

**Website and pilot manual:** the GitHub Pages site of this repository (`index.html`, `manual.html`). The DTM Planner runs online at `planner/`, as part of the WW DTC Planner (MiG-29A, F-15C and Su-27 / J-11A).

## Requirements

- DCS World with the F-15C (Flaming Cliffs)
- Optional: SRS (DCS-SimpleRadio Standalone) for the RADIO page

## Install

1. Download the zip from the [1.2 release](https://github.com/WWNyuu/F15C-SIT-WW/releases/tag/1.2) and unzip it so the folder sits at `Saved Games\DCS\Mods\tech\F-15C SIT (WW)`.
2. Close DCS and double-click `INSTALL.bat` in that folder.
3. Bind the castle switch, auto acquisition, weapon select and the rest in Options > Controls > F-15C, category "F-15C SIT". `F-15C SIT Controls Guide.pdf` in the zip lists every control.

Run `INSTALL.bat` again after every DCS update or repair (it puts the add-on's controls back). `UNINSTALL.bat` takes everything out again.

## Repository

- `downloads/` - the release zip (also attached to the GitHub release)
- `mod/F-15C SIT (WW)/` - the same add-on as source (cockpit device and page, export script, hook, options, installer, DTM Planner)
- `planner/` - the WW DTC Planner for the browser (F-15C, MiG-29A, Su-27 / J-11A)
- `index.html`, `manual.html`, `img/` - the website

## Credits

DCS World and the F-15C: Eagle Dynamics. Planner maps: Natural Earth, NOAA DEM. A fan-made add-on, not affiliated with Eagle Dynamics.
