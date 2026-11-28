## ADDED Requirements

### Requirement: Needs, and the rooms that meet them
The Commander's hunger and fatigue SHALL rise over time, and grime SHALL rise outside. A galley SHALL feed the
Commander, from the doll's stores and then from rations. Quarters SHALL let the Commander sleep, a bath wash, and a
med bay clear the dose and mend the suit. A starving or exhausted Commander SHALL not mend aboard, and SHALL slowly
wear down outside. The visor SHALL warn as needs near full.

#### Scenario: A meal and a night
- **WHEN** a hungry and tired Commander uses a galley and then quarters
- **THEN** hunger and fatigue are back to zero, with a feedback bundle each time

### Requirement: Dolls need upkeep
A doll's engine wear SHALL grow while it moves and SHALL cost top speed above half. Its engine room SHALL reset the
wear. Life support SHALL wear while the Commander is aboard; when it is spent, the doll SHALL no longer restore the
suit, until it is serviced. A biotope's crop SHALL ripen, and harvesting it SHALL give rations. The cockpit screens
SHALL show the state of the engines and the air.

#### Scenario: An overhaul
- **WHEN** a worn doll's engine room is used
- **THEN** its wear is zero and it reaches its full speed again
