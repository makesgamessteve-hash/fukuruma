# sensor-system Specification

## Purpose

How the dolls see danger: hazard signatures, a sensor suite per doll, passive scans and active pings, ageing contacts drawn on the visor and windows, and autopilots that stop for known hazards.

## Requirements

### Requirement: Signatures and suites
Every hazard SHALL have a signature: a kind, a size and a stealth. Every doll SHALL have a sensor suite: a range, a
resolution and the kinds it covers. A suite SHALL detect a hazard only if all of these hold:
- the hazard's kind is one the suite covers;
- the hazard is at least the suite's resolution in size;
- the hazard is within the suite's range, shortened by the hazard's stealth on passive scans.

#### Scenario: Below the Walker's resolution
- **WHEN** a 0.2 m gas pocket lies between the Walker and the Exosuit
- **THEN** the Walker's passive scans miss it, and the Exosuit's find it and show it on the visor

### Requirement: Active pings
The scan command SHALL ping. A ping reaches twice the suite's range, resolves half its resolution and ignores stealth.
Every hostile within its reach SHALL be alerted.

#### Scenario: A predator hears the ping
- **WHEN** the Commander pings with a predator 200 m away, beyond passive range
- **THEN** the predator becomes a contact and is alerted

### Requirement: Ageing contacts and overlays
Scan data SHALL be kept as contacts holding where and when each hazard was last seen. Contacts older than a minute
SHALL be shown as stale, with their age. Contacts SHALL be drawn where they are on the visor and through the cockpit
windows, and the cockpits SHALL show a sensor screen.

#### Scenario: An old contact
- **WHEN** a contact was last seen more than a minute ago
- **THEN** its marker is dimmed and says how long ago it was seen

### Requirement: Autopilot hazard stops
A doll on autopilot SHALL stop when a known contact lies in its way and is big enough to matter to it. It SHALL then
hand back control.

#### Scenario: A sinkhole on the Walker's way
- **WHEN** the Walker goes on autopilot towards the Land Explorer with a 40 m sinkhole 500 m ahead
- **THEN** its sensors find the sinkhole, and the Walker stops short of it with the ship AI saying why
