# Plain As Day · SOHO 1854

**Plain As Day** is a history mystery game. In **SOHO 1854** you are Henry
Whitehead, a curate in London during the Broad Street cholera outbreak. You
knock on doors, listen to the neighbours, fill in the case of each house in your
notebook and mark every death on a map of the parish, until a doctor named John
Snow comes to your door with a different idea.

**Play it free in the browser:** [merryllerena.itch.io/plain-as-day](https://merryllerena.itch.io/plain-as-day)

This repository holds the source code of the game.

## Built with

- [Godot Engine 4.7](https://godotengine.org), written in **GDScript**.
- Story, dialogue, houses and evidence stored as **JSON** in `data/`.
- 3D assets by [Kenney](https://kenney.nl) (CC0) and fonts EB Garamond and
  Pinyon Script (SIL OFL). See [CREDITS.md](CREDITS.md).

## How the code is organised

| Folder | What is there |
|---|---|
| `scripts/autoload/` | Global systems: game state, notebook, dialogue runner, save, HUD |
| `scripts/world/` | The street, the houses and every scene built in code |
| `scripts/ui/` | Menus, notebook pages, pause, chapter end |
| `scripts/herramientas/` | Automated tests and capture tools |
| `data/` | Dialogue, notebook cards, streets and doors, historical evidence |
| `scenes/` | Godot scenes |

Highlights:

- **Streets built from data.** `scripts/world/constructor_calle.gd` and
  `scripts/world/fachadas.gd` raise every Victorian house, shopfront, door
  number and chimney from `data/barrio/soho.json`, merging the geometry so the
  game runs smoothly in a browser.
- **The notebook.** `scripts/autoload/cuaderno.gd` keeps the words the player
  has heard and checks each card: right words are inked in, wrong ones are
  marked in red, and a complete card is sealed as evidence.
- **Dialogue from JSON.** `scripts/autoload/dialogue_runner.gd` plays branching
  conversations with conditions and flags, and lets the player go back for
  anything they missed.
- **Tests.** The scenes in `scenes/herramientas/prueba_*.tscn` check the script,
  the doors, the navigation and the guide, and one plays the whole chapter with
  simulated clicks.

## Run it

1. Install [Godot 4.7](https://godotengine.org).
2. Open `project.godot`.
3. Press Play.

## Licence

Copyright (c) 2026 Merry Llerena. All rights reserved.

You may read the code here, but you may not copy, modify, publish or use any
part of it without written permission. See [LICENSE](LICENSE).
