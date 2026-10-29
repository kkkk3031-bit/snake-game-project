# Game Brief: Snake

**One-sentence pitch:** Classic grid snake — eat, grow, speed up, and don't bite yourself.

## Core loop
- Steer the snake toward the food on a fixed grid.
- Eating adds one segment and one point; every few points the snake speeds up.
- The longer you get, the less room you have, so every run gets tenser until you crash.

## Player goal & fail state — what "working" looks like
- Goal: beat your best score (saved between sessions). Filling the whole board wins.
- Fail: the head hits a wall or the snake's own body. Restart takes one key press.

## MVP — what must exist to be the game
- 20×20 grid; the snake starts at length 3, moving right.
- Arrow keys / WASD steering, with a 2-move input buffer and no instant 180° reversal.
- Food spawns only on free cells; eating grows the snake and scores +1.
- Speed rises every N foods, down to a minimum tick length (data-driven).
- Wall and self collision end the run; you may move into the cell the tail is leaving.
- HUD with score and best score; pause (P / Space) and restart (R / Enter).

## Out of scope — not building this
- No audio, power-ups, levels, obstacles, multiplayer, or menus beyond start, pause and game over.

## Build order
1. Pure snake logic plus unit tests (movement, growth, collision, input buffer).
2. Render the grid and HUD, and wire up input and the tick timer.
3. Save the best score; add the pause, game-over and win overlays.
4. HTML5 port (`web/`) with the same rules and swipe controls.

---
**Who it's for / what they feel:** Anyone who wants a quick two-minute "one more try" session.

**Art & audio direction:** Flat dark board, neon-green snake, coral food, no audio.

**Reference game:** Nokia Snake II — the core loop only, with walls that kill.
