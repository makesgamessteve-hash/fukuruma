## Purpose

The cockpit or bridge around every doll's seat: windows, screens, controls and how far the Commander's head turns.

## ADDED Requirements

### Requirement: A cabin at every doll's controls
Every doll steered from a seat SHALL have a cabin around it, sized for the Exosuit. The cabin SHALL have windows to
look out of, a console with screens, and control sticks with the Commander's hands on them.

#### Scenario: Seats up the chain
- **WHEN** the Commander sits at the controls of the Walker, the Land Explorer and the Continental Explorer
- **THEN** each view shows its cabin and the world through its windows, matching the reference images

### Requirement: Screens
A doll's screens SHALL show its name, what it holds docked, the dolls around it and how far away they are, its
altitude, and the controls. Their text SHALL appear on the screens and fit them. At a doll's controls, the screens
SHALL replace the visor HUD.

#### Scenario: What the Walker knows
- **WHEN** the Commander sits in the Walker
- **THEN** its screens name it, show an empty hold and the Land Explorer's distance, and all three can be read

### Requirement: The seat rig
In a seat, the Commander's head SHALL turn at most 110° to either side of the doll's front.

#### Scenario: Looking back
- **WHEN** the Commander tries to look straight back from a seat
- **THEN** the view stops at the limit
