## Purpose

Makes skies, sunsets, hazes and the limbs of worlds from each world's air by scattering the star's light, the same
model from the ground and from space.

## ADDED Requirements

### Requirement: Scattering
The renderer SHALL scatter the star's light through the current world's air along each view ray (Rayleigh and Mie
scattering and absorption, falling off with height, shadowed by the world) and dim what lies behind by the air's
transmittance. Rays that meet the world beyond the drawn scene SHALL see its lit surface colour.

#### Scenario: A thick-aired world at dusk
- **WHEN** the range stands on the home world with its star low behind the camera
- **THEN** the sky glows from the air's scattering and the horizon shows the distant surface, matching the reference image

### Requirement: Air from data
Each world's air SHALL come from its descriptor's optics (gas, pressure, scale height), and the same air SHALL be used
from orbit (scaled consistently in scaled space) and from the ground.

#### Scenario: Different gases
- **WHEN** the range jumps to worlds with other air and other stars
- **THEN** their skies take different colours, matching their reference images
