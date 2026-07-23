# ChessLab 1.0.1 — release notes

## What's new

- **Progress** — a new dashboard, reachable from the home screen, that brings
  together what you've accomplished: your record against Stockfish (wins,
  draws, losses, highest Elo beaten, results by opponent level) and puzzles
  (success rate, level reached, success by difficulty, themes to work on).
  Each weak theme starts a targeted puzzle set in one tap. Everything is
  computed locally, from what you've already played.
- **Scanner — improved piece recognition**: the recognition model was
  retrained on a much wider variety of piece sets and boards, for more
  reliable reading of screenshots and photos.
- **Help — "Contact the developer"**: a new section at the bottom of Help
  invites you to send feedback and suggestions, and to report a bug by email
  (with your iPhone/iPad model and iOS version). Available in French and
  English.
- **iPad — redesigned home screen**: on the large screen, the mode grid no
  longer spreads out into a thin row — three columns with larger tiles, and an
  ambient background scaled to the screen rather than calibrated for iPhone.

## Fixes

- **Crash when leaving the Analysis screen.** In some cases, closing Analysis —
  particularly via "Play from here", or while a game was still being analyzed —
  could close the app. The chess engine is now stopped reliably when you leave
  the screen, with no risk of the app closing.

## Under the hood

- Full hardening of the chess engine lifecycle: guaranteed shutdown when
  leaving the screen (even during a background analysis), automatically
  verified memory release, and protection against closures caused by engine
  communication. Three distinct causes of the same symptom, all closed.
- Removed the "Engine diagnostic" screen from Settings: a leftover development
  tool with no real use (engine-failure detection and the "Retry" button are
  already built into each relevant mode).
- Removed an old personal-repertoire module that had become unreachable: no
  screen led to it anymore after the Openings redesign. The ECO library and
  line-by-line training are unchanged.
