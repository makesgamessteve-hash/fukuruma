## Purpose

Playing every doll by touch: a stick on the left, looking by dragging on the right, and the buttons where the
Commander is.

## ADDED Requirements

### Requirement: A touch layout per doll
The touch buttons SHALL be the ones for where the Commander is. On foot they SHALL be the suit's. At a doll's controls
they SHALL be the chain's actions that apply there, and climb and dive in flying dolls. Buttons not in the layout
SHALL be neither drawn nor pressed.

#### Scenario: From the Exosuit to the Walker and back
- **WHEN** on a touch screen the Commander taps UP on foot, then DOWN in the Walker
- **THEN** the Walker is boarded with its own buttons shown, then the Commander is on foot again, and both layouts
  match their reference images

#### Scenario: Climbing by touch
- **WHEN** the Commander holds CLIMB in the Continental Explorer
- **THEN** it climbs
