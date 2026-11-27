# rivers-and-lakes Specification

## Purpose

Rivers, lakes and falls on the land around the range of a world with water, worked out from how water runs over its
ground.

## Requirements

### Requirement: Water courses
On a world with water, the ground around the range SHALL have:
- lakes, where its basins fill;
- rivers, where enough ground drains through a point, in channels carved into the ground.

Rivers SHALL run downhill to a lake, the sea or out of the square. The same world SHALL always have the same water
courses. The range's levelled site SHALL stay as it is.

#### Scenario: Around the range
- **WHEN** the water courses of a world are worked out twice around the same place
- **THEN** both have the same rivers and lakes, and a river's channel lies below the plain ground

#### Scenario: Into the sea
- **WHEN** the square around the range reaches the shore
- **THEN** a river pours into the sea

### Requirement: Water surfaces
Rivers and lakes SHALL be drawn as glossy water surfaces: lakes flat at their level, rivers along their courses. Where a
river drops steeply or pours into the sea, its water SHALL be white.

#### Scenario: From the banks
- **WHEN** a lake, a river and a fall around the range are seen from their banks
- **THEN** the pictures match their reference images
