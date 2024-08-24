# Duck Hunt in SQL*
_No SQL knowledge necessary. It's actually mostly_ ***PL/pgSQL** _, heavily unoptimized and undocumented. What could go wrong?_

## Installation

Install the game by running `./play.sh`. You will need Docker running on your machine.

## Gameplay

![Gameplay](./assets/duckhunt-sql.r10.gif)

1. Start a new game by running `select start()`
    Optionally, `select start(2)` to start at a higher level.
2. Your `INFO:           🚀1   💥2    🔼↘` bar is useful
    This says Level 1, 2 shots left for this duck, and the direction that the duck is flying is bottom right.
3. Your crosshair is a block `█`
    It starts in the center of a 16x16 grid, and you move it relative to its current position when you shoot.
4. Your target is the duck 🦆
    It starts at the bottom of the grid, and randomly flies around the grid.
5. Timing is crucial
    The duck moves even if the screen doesn't. The longer you idle, the more the duck's flown around. `select shoot(dx,dy)` where the duck is flying to, and `select refresh()` if you feel you waited too long.
6. Your score ` 🫥  🦆 🦆 🦆 🦆 🫥 ` is at the bottom
    If you hit the duck, you score a 🦆. Run out of shots, the duck escapes 🫥. 
7. Stop the game by running `select stop()` and exit by running `exit`
    When you come back, the old game does not resume.
8. Good luck, try to get all the 10 ducks in a game!

## Controls

1. Shoot by running `select shoot(dx,dy)`
    e.g. `select shoot(-1,2)` will shoot at a new position that is 1 left and 2 down from the current crosshair location.
2. If you idle, run `select refresh()`
    This refreshes the view without losing a shot.


## Pre-requisites

1. Docker
2. Basic Math skills
3. Zen
