# ChessLab 1.1.0 — release notes

## What's new

- **Redesigned iPad & Mac interface.** On iPad (full screen) and Mac, the app
  now uses a persistent sidebar (Modes + Tracking) with a detail area, instead
  of a scaled-up phone layout. iPhone keeps its familiar tile grid.
- **Edge-to-edge board on iPad.** In "Play against the computer", the board now
  fills the screen — full height in landscape (with the evaluation bar moved
  beside the move list), full width in portrait. Two Players and Puzzles also
  adapt to the large screen (Puzzles gets a two-column board + info layout).
- **"Against the computer".** The opponent is now called "the computer" instead
  of "Stockfish" throughout the interface — clearer for players who don't know
  the engine by name. Stockfish is still credited in Help and Licenses.
- **iCloud sync (optional).** Turn it on in Settings so your games, puzzles and
  progress follow you across your devices, via your own private iCloud. No
  account to create, no ChessLab server. Off by default — the app works fully
  offline.
- **Mac menus.** Every mode now has a keyboard shortcut (Openings ⇧⌘O,
  Laboratory ⇧⌘L), and Progress joined the menu (⇧⌘R).

## Under the hood

- Engine lifecycle hardening: a crash on Laboratory startup (writing to an
  engine that failed to launch) is fixed, and watchdog stops now go through the
  same safety guard as every other engine write.
- Shared route mapping between the iPhone stack and the iPad/Mac split view: a
  single source of truth for navigation, whatever the layout.
