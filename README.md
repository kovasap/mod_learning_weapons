# Learning Weapons

## Description

This mod removes all weapon perk groups from new brothers, but adds the ability
for brothers to gain any weapon perk groups they want by using the weapon in
battle.

This works by tracking the number of kills each brother gets with each weapon
type, which can be seen by hovering over the EXP bar in the roster screen.

Once a brother gets 20 kills with a weapon, they are then permanently granted
that weapon's perk group.

Additionally, unlocking perk groups requires 5 special kills, thematic to that
weapon type:

 - Bows: kills at range 5 or more.
 - Throwing Weapons: kills at range 2.
 - Crossbows: kills on targets that still have armor when they die.
 - Cleavers: decapitations.
 - Axes: headshots.
 - Swords: riposte kills.
 - Flails: kills on shield wielders.
 - Polearms: kills when surrounded by 2 or more friendly units.

## Implementation

Additionally, this mod adds a new origin that includes a brother carrying each
weapon type, and where the kill thresholds to get perk groups and lowered to one
normal kill and one special kill.
This is to help test that the mod works.

## Motivation

In Battle Brothers Reforged, there are a lot of variables that go into
generating a new brother.
This makes it so that it is hard to have much control over how you want to build
your entire company without going through many, many potential hires.
See some more context on this at
https://discord.com/channels/1006908336991645757/1528585551412990125.

To help manage this a bit, this mod gives some control back to the player by
essentially giving all weapon perk groups to all brothers, albeit gated behind a
bit of progression.
