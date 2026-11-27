## ADDED Requirements

### Requirement: One-sided surfaces and frame statistics
Draws SHALL be able to keep their normals on back faces (closed surfaces seen from outside), and scripts SHALL read
the number of draws and triangles recorded in the current frame.

#### Scenario: Counting
- **WHEN** a planet is drawn
- **THEN** fk.gfx.stats() gives the draws and triangles it added

### Requirement: Exposure against space
Automatic exposure SHALL meter empty sky as at least dim, so a lit body against black space is exposed for its
surface.

#### Scenario: A planet in space
- **WHEN** a sunlit planet fills a third of an otherwise empty view
- **THEN** its surface is not blown out to white
