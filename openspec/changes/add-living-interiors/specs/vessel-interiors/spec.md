## ADDED Requirements

### Requirement: Rooms for living in every doll
Every doll except the Exosuit SHALL have a galley, quarters, a bath, a med bay, an engine room and a cargo deck, with
more quarters the bigger it is. Dolls from 1 km SHALL also have a workshop, a lab, life support and a drone bay. Dolls
from 6 km SHALL also have a biotope. Each room type SHALL have its own furniture and lights, and one fixture the
Commander uses.

#### Scenario: A big doll's rooms
- **WHEN** the Continental Explorer's layout is made
- **THEN** it has all these rooms, a biotope taller than the other rooms, and a fixture in each

### Requirement: Rooms stream around the Commander
Rooms SHALL be built only near the Commander on foot, a few a frame, and SHALL be let go when far. The corridor and
the hangars SHALL stay built. A door that opens or shuts SHALL rebuild only its room.

#### Scenario: Walking down a long doll
- **WHEN** the Commander walks from one end of the Jump Ship's corridor to the other
- **THEN** the rooms at the far end are built, and those left behind beyond the unload distance are let go
