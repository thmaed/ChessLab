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
- **iCloud sync (optional).** Turn it on in Settings so your saved games and
  your puzzle progress follow you across your devices, via your own private
  iCloud. No account to create, no ChessLab server. Off by default — the app
  works fully offline. (The built-in puzzle library stays on-device; only your
  personal progress travels.)
- **Board & piece themes.** Choose among four board colours (Classic, Blue,
  Walnut, High-contrast) and three piece sets (Classic, Modern, Bold), with a
  live preview right in Settings.
- **Pointer & trackpad.** On iPad (with a trackpad or mouse) and Mac, the square
  under the pointer is now highlighted as you hover the board.
- **Mac menus.** Every mode now has a keyboard shortcut (Openings ⇧⌘O,
  Laboratory ⇧⌘L), and Progress joined the menu (⇧⌘R).

## Under the hood

- Rebuilt chess engine integration: Stockfish is now compiled from source with
  ARM SIMD (NEON) optimizations and driven off the main thread. Result: much
  faster analysis and no more interface stutter while the engine thinks,
  especially on older devices. Engine strength and settings are tuned to each
  device — deeper analysis on recent hardware, lighter on older phones.
- Faster post-game analysis: once every move is evaluated, review navigation is
  served from the cache and the engine stays idle instead of recomputing on each
  step — while analysing a specific position still runs live.
- Reliable "Resume game" after leaving via the system back button.
- Engine lifecycle hardening: a crash on Laboratory startup (writing to an
  engine that failed to launch) is fixed, and watchdog stops now go through the
  same safety guard as every other engine write.
- Shared route mapping between the iPhone stack and the iPad/Mac split view: a
  single source of truth for navigation, whatever the layout.
