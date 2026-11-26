# Tasks

## 1. Engine (C)

- [x] 1.1 `anim/anim.c`: rest pose, clip sampling (linear/slerp, step, cubic), blending, additive layers, node matrices
- [x] 1.2 Frame bone list, bone texture upload, skinning in `common.glsl`, `gbuffer.glsl`, `shadow.glsl`
- [x] 1.3 `fk.anim.pose` and its methods; `fk.gfx.draw(model, m, { pose })`

## 2. Game (Lua) and content

- [x] 2.1 `fk/anim.lua`: phase-synchronised 1D blend trees with events, state machines with crossfades
- [x] 2.2 `fk/spring.lua`
- [x] 2.3 Exosuit antenna joint

## 3. Tests

- [x] 3.1 C unit tests: sampling of every interpolation, blending (shortest arc), additive layers, node matrices, frame bones
- [x] 3.2 Lua tests: poses, weights, additive, rotate, argument checks, trees, machines, springs
- [x] 3.3 `tests/game/showcase_skinning.lua` with a golden image

## 4. Verification

- [x] 4.1 Coverage gates, sanitizers, all CTest tests, web build and browser tests
- [ ] 4.2 CI green on every target; Pages updated
- [ ] 4.3 `openspec validate add-animation-runtime --strict`; archive after deployment
