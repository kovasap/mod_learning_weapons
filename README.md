# Learning Weapons

## Description

This mod removes all weapon perk groups from new brothers, but adds the ability
for brothers to gain any weapon perk groups they want by using the weapon in
battle.

This works by tracking the number of kills each brother gets with each weapon
type, which can be seen by hovering over the EXP bar in the roster screen.

Once a brother gets 20 kills with a weapon and 1 special achievement with it, they
are then permanently granted that weapon's perk group.

The special achievements are:

 - Bows: Sniper - Get a kill at range 5 or more.
 - Throwing Weapons: Come at me! - Get a kill at range 2 on an enemy not engaged
   with any friendly units.
 - Cleavers: Mercy Killer - Decapitate a bleeding enemy.
 - Crossbows: Shell Cracker - Get a kill on an enemy that still has armor
   remaining when they die.
 - Axes: Executioner - Kill an enemy with a headshot.
 - Swords: Duelist - Kill an enemy with a riposte.
 - Flails: Talented - Kill an enemy wielding a shield with a headshot.
 - Polearms: Savior - Move an enemy away from an injured friendly unit with
   Repel or Hook.
 - Daggers: Assassin - Kill an enemy with a chestpiece of 75% condition or
   higher.
 - Hammers: Can Opener - Fully destroy an enemy's armor (head and chest) from
   100% to 0% without injuring them.
   This can happen over multiple hits, but the enemy cannot take damage from any
   other source.
 - Maces: Heavy Hitter - Kill a stunned enemy.
 - Spears: Hold your ground! - Kill an enemy with spearwall.

The achievements must be earned while wielding a weapon of the type the
achievement is for.  Hybrid weapons work for both weapon types.

When hovering over the EXP bar to see progress on each weapon, show the progress
towards the 20 kills, then show a check or x next to "Complete <achievement
name>".
To see the achievement description, use the reforged nested tooltips feature.
Add nested tooltips in achievement descriptions as well where appropriate (such
as for the ability names in the polearms description).

When an achievement is completed, show it in the combat log in extra visible
font (e.g. bolded).

## Implementation

The mod requires Reforged, Dynamic Perks, and MSU. It uses Reforged's
`pgc.rf_weapon` perk groups and adds a hidden serialized skill to each brother
that stores normal kills, special kills, and whether a perk group was unlocked.

Additionally, this mod adds a new origin, "Learning Weapons - Test", that
includes one brother carrying each weapon type, and where the kill thresholds to
get perk groups are lowered to one normal kill and one special kill.
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
