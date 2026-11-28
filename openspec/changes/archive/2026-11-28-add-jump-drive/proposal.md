# Proposal

## Why

The Jump Ship is the doll that jumps between stars (CONCEPT §2.2, §2.4), and the plan moves the jump to its bridge in
M6. Until now a jump could start anywhere, even on foot, and the whole chain went along.

## What Changes

- A jump happens only with the Commander on the Jump Ship's bridge. A jump command from anywhere else changes nothing.
  The maps still open anywhere, for looking.
- Every doll belongs to the star system it was deployed in. Only the Jump Ship goes along with a jump. Everything else
  stays behind in its system, and comes back into view on the return.
- Dolls in other systems are left out of drawing, boarding, targets, the screens and the physics: their leg columns are
  removed, and remade on the return. An Exosuit left behind means the suit is neither simulated nor drawn, and the
  ground streams in around the Commander's doll instead.
- From the Jump Ship's holds the Commander can deploy a new chain in the new system.

## Capabilities

### Modified Capabilities
- `travel`: the jump drive is on the Jump Ship's bridge, and what it deployed stays in its system.

## Impact

Changed: `data/scripts/{chain,main,universe}.lua`. The navigation scenario now jumps from the bridge, so its arrival
goldens and recorded hash change on purpose. `tests/lua/chain_test.lua` is extended.
