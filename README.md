# OmaClass

Classroom controls in the Omarchy bar, through [Veyon](https://veyon.io).
Click the bar icon to see who's online, then lock screens, message the class,
open a website on every computer, view or take control of one student's
screen, or jump to the full Veyon classroom view.

Prototype (0.1.0), teacher side only. Tested from an x86_64 Omarchy laptop to an
Omarchy student on an Apple Silicon MacBook: view, lock, message and remote control work.

## Needs

- Veyon 4.11+ with key-file auth. The AUR package is older, so
  `packaging/veyon/PKGBUILD` builds 4.11.4 (x86_64 and aarch64) with two
  patches Hyprland needs; build it with `makepkg -si`. Then add the
  student computers as a room (`veyon-cli networkobjects add ...`).
- On Hyprland students, `wayvnc -r 127.0.0.1 5900` plus Veyon's External VNC
  server plugin (Hyprland's portal has no RemoteDesktop interface).

## With OmaMastery

If [OmaMastery](https://github.com/seawolf-seno/omamastery) is installed, OmaClass
takes its class list from it (`omamastery classes --json`), opens on the class
happening now, shows each class's computers from the Veyon room named in its
`class.toml`, and adds a Mastery button. Sample mode then shows OmaMastery's
made-up classes. Without it, OmaClass lists Veyon's rooms.

## Use

```sh
omarchy bar put omaclass --section right --index 0
omarchy bar set omaclass sampleClass true --json   # made-up class, for demos
```

Click a student to view their screen; right-click to take control.
"Present" (show the teacher's screen) is not working on Omarchy yet.

## Safety

All Veyon calls go through `bin/omaclass-veyon`, which passes hosts and text
as separate arguments (no shell), allows only lock, message and open-website,
and refuses anything else. Screen monitoring of students needs the school's
consent policy before classroom use.

## Tests

```sh
node --test tests/ && python3 -I -m unittest discover -s tests -p "test_*.py"
```
