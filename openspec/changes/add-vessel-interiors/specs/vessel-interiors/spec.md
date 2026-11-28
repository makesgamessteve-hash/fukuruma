## ADDED Requirements

### Requirement: Rooms made for people
Every doll SHALL have a fixed interior at human scale:
- a corridor from its bridge, where the doll's seat is;
- side rooms behind doors: a suit bay where the doll carries the Exosuit, the Jump Ship's clone bay, and quarters;
- one hangar per kind of doll it carries, holding that doll at full scale with a ramp up into it.

#### Scenario: The Walker's rooms
- **WHEN** the Walker's interior is built
- **THEN** its seat, its suit bay and its exit can all be stood at, and its bridge seat is where the doll's seat is

### Requirement: Walking as a human
Inside a doll, the Commander SHALL walk as a human. Walls SHALL stop the Commander, who slides along them. A shut
door SHALL block the way, and a door SHALL NOT close on the Commander standing in it. Door states SHALL be saved.

#### Scenario: A shut door
- **WHEN** the Commander shuts the suit bay door, saves, opens it, and loads
- **THEN** the door is shut again and the Commander cannot walk through it until it is opened

### Requirement: The use command
F, the gamepad's B or the touch use button SHALL do what is in reach, and the visor SHALL show what it would do:
- go in through the suit bay from the Exosuit;
- stand up from the seat;
- take the controls;
- open or close a door;
- walk up a ramp into a docked doll, and down it again;
- launch a docked doll from its bridge;
- suit up in the suit bay and go out.

#### Scenario: In and out of the Walker
- **WHEN** the Commander presses F beside the Walker, walks to its bridge, takes the controls, stands up, goes to the
  suit bay and presses F
- **THEN** the Commander is first inside on foot, then at the Walker's controls, and finally outside in the Exosuit

#### Scenario: Boarding a docked Drop Ship
- **WHEN** the Commander walks up the Drop Ship's ramp in the Jump Ship's hangar and uses its seat
- **THEN** the Drop Ship launches from the hold with the Commander at its controls
