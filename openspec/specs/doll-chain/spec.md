# doll-chain Specification

## Purpose

The Fukuruma chain: its dolls as data, where they stand, and how the Commander deploys, recalls and boards them.

## Requirements

### Requirement: Dolls are data
Every doll SHALL be defined in Lua: its size, what it carries docked, where it stands once deployed, its seat and its
hull parts. Mods SHALL add dolls the same way. Each doll's hull SHALL be built from its parts at its real size.

#### Scenario: The registry
- **WHEN** the dolls are listed
- **THEN** the Jump Ship is 144 km, the Space Station 31 km, the Continental Explorer 6.7 km, the Land Explorer
  1.44 km, the Walker 72 m, the Exosuit 3.6 m and the Drop Ship 100 m, and each hull is about its doll's size

### Requirement: The chain
The simulation SHALL hold which dolls are out in the world, where they stand, what each holds docked, and which one
the Commander is in. A new game SHALL start with the whole chain out, from the Jump Ship down to the Exosuit, and the
Commander on foot. The chain SHALL be part of the saved game.

#### Scenario: From the range
- **WHEN** a new game starts and the Commander looks south from the range
- **THEN** the chain stands there, matching the reference image

### Requirement: Deploy, recall, board
The Commander SHALL be able to:
- deploy a doll that the current doll holds docked, beside it;
- recall a child doll that has no doll of its own out;
- board the parent doll or a child doll within reach, and look out from its seat.

Commands that break these rules SHALL change nothing. Away from the Exosuit, the suit SHALL stand still.

#### Scenario: Up the chain and back
- **WHEN** the Commander boards the Walker, the Land Explorer and the Continental Explorer in turn, then comes back down
- **THEN** each seat's view matches its reference image, and the Commander is on foot in the Exosuit again

#### Scenario: The Exosuit in and out
- **WHEN** from the Walker the Commander recalls the Exosuit and deploys it again
- **THEN** the suit stands beside the Walker

### Requirement: Watching the chain
At a doll's controls, the survey drone SHALL circle that doll at a distance scaled to its size. The ship AI SHALL name
each deploy, recall, boarding, teleport and autopilot event in a line of text. A deployed doll SHALL be seen easing
out of its parent. Dolls SHALL be drawn at any distance.

#### Scenario: From the Walker and the Land Explorer
- **WHEN** the Commander boards the Walker, looks through the drone, then deploys a Walker from the Land Explorer
- **THEN** the ship AI greets the Commander, the drone circles the Walker, the new Walker eases out of the Land
  Explorer, and the views match the reference images

### Requirement: Solid legs
The legs of the dolls standing on the ground SHALL be solid to the suit and to other bodies. They SHALL move with
their doll and be gone once it is recalled.

#### Scenario: Walking into a Walker's leg
- **WHEN** the suit walks straight at one of the Walker's legs
- **THEN** it stops at the leg, and after a recalled Walker its legs are gone from the physics world

### Requirement: The whole chain, down and back up
The Commander SHALL be able to travel the whole chain in one run, in first person: up from the Exosuit to the Jump
Ship, down again to a freshly deployed Exosuit and walk on, and back up with every new doll recalled into its parent's
hold.

#### Scenario: The Fukuruma test
- **WHEN** the Fukuruma test runs from a new game
- **THEN** every step succeeds, and the views on foot and back on the Jump Ship match the reference images
