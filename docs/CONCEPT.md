# Fukuruma — Game Concept

> Status: **v0.2**. Updated with the answers to the ten clarifying questions (see §10, *Decisions*).
> The build plan is in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

Fukuruma is a retro-3D space exploration game about **wonder** and **scale**. You command a
moon-sized Jump Ship. It carries space stations, which carry mountain-sized explorers, which carry
walking cities, which carry giant walkers, which carry you: the Commander in an environmental
exosuit, the last and smallest doll. Every doll can be entered, walked through and deployed.
Every planet is worth going down to, and any planet can kill you.

---

## 1. Pillars

1. **Wonder of exploration.** Every star system has at least one thing you have never seen before.
   Generation is physically inspired and artistically directed: a "Wonder Director" keeps the
   galaxy surprising.
2. **Fukuruma (the nesting doll).** Seven nested scales. Each doll is a vehicle you fly, drive or walk,
   and you can explore every one of them inside. Going *down* the chain brings you closer to
   discoveries and to danger. Going *up* the chain is how you survive.
3. **Real danger, read through sensors.** You never walk in blind, but every sensor has a range and
   a resolution. Big vehicles see big threats and miss small ones. The exosuit sees the things that
   kill people.
4. **Survive, don't conquer.** Scanning, avoiding, outrunning and outsmarting come first. Weapons are
   few, defensive and costly to use.
5. **Retro 3D craft.** Late-90s PC look: low resolution, a palette per world, dithering, low-poly
   models, billboard sprites and voxels.
6. **Open and moddable.** A C engine with the game itself in Lua. Assets, scripts and shaders live in
   folders beside the binary. Mods are folders you drop in.

---

## 2. The Fukuruma Chain

### 2.1 Scale table

The ×20 steps are **heights**. The ×100 steps are **volumes**, which is ×4.64 in length. Each ×100
step can therefore carry a handful of the next doll, not a hundred.

| # | Doll | Rule | Height / length | For comparison |
|---|------|------|-----------------|----------------|
| 0 | Human (the Commander) | — | 1.8 m | — |
| 1 | **Exosuit** | 2 × human height | **3.6 m** | an elephant on its hind legs |
| 2 | **Exploration Walker** | 20 × Exosuit height | **72 m** | a 24-storey building |
| 3 | **Land Explorer** | 20 × Walker | **1.44 km** | 1.7 × Burj Khalifa: a walking city |
| 4 | **Continental Explorer** | 100 × Land Explorer volume | **≈ 6.7 km** | most of Mount Everest, flying |
| 5 | **Space Station** | 100 × Continental Explorer volume | **≈ 31 km** | larger than Mars's moon Phobos |
| 6 | **Jump Ship** | 100 × Space Station volume | **144 km** | a small moon |
| — | **Drop Ship** | outside the chain | ≈ 100 m (proposal) | the Commander's shuttle between dolls |

Every size is Lua data (`data/scripts/dolls/*.lua`), so retuning the chain changes content, not code.

### 2.2 The dolls

- **Jump Ship (144 km).** A moon-sized mothership. It jumps between stars and parks in high orbit
  or at a Lagrange point; from the planets it looks like a new moon. Inside: station hangars, drone
  foundries, engineering, the bridge, the research decks, the clone bay and the Commander's quarters.
  It holds a few Space Stations.
- **Space Station (31 km).** It is deployed into orbit around one planet and becomes that planet's
  base: scanning, teleport node, trade port, workshop. From the surface it is a bright fast "star".
  It holds a few Continental Explorers.
- **Continental Explorer (6.7 km).** A flying mountain that cruises low through the atmosphere and
  crosses continents in hours. It cannot enter canyons, forests or caves. It deploys Land Explorers.
- **Land Explorer (1.44 km).** A slow, armoured walking city, the base camp of an expedition. It
  deploys Walkers.
- **Exploration Walker (72 m).** The agile giant, with legs, manipulators, a sample bay and the
  Exosuit dock.
- **Exosuit (3.6 m).** The only doll that fits into caves, ruins, native villages and ship corridors.
  It is the Commander's life.
- **Drop Ship (≈ 100 m).** It takes the Commander from a station down to a Continental Explorer
  ("board a drop ship to the planet"), and between any two dolls where there is no teleporter.

### 2.3 Scale is level of detail, made into gameplay

Each doll matches one level of detail of the world:

| Doll | What its world is | Terrain detail it needs |
|------|-------------------|-------------------------|
| Jump Ship | the star system | bodies as spheres, orbits |
| Space Station | one planet | continents, oceans, storms, biomes |
| Continental Explorer | a continent | mountain ranges, rivers, regions (~50 m) |
| Land Explorer | a region | hills, forests, canyons (~5 m) |
| Walker | a valley | rocks, trees, creatures (~0.5 m) |
| Exosuit | a few hundred metres | voxels, caves, small life, artefacts (~0.25 m) |

Exploration moves down the same level-of-detail pyramid the renderer needs anyway. The player never
sees the engine switch detail levels. They see the next doll being deployed.

### 2.4 Movement and travel

- **Jump Ship:** jumps between systems; moves on rails inside a system.
- **Teleport network:** the Commander teleports between the Jump Ship and every deployed station.
- **Space Station:** fixed in orbit once deployed; can be recalled.
- **Drop Ship:** flies from station to surface and between dolls.
- **Continental Explorer:** flies across the planet; autopilot with time compression.
- **Land Explorer / Walker:** drive or walk; autopilot to waypoints. Autopilot stops when the sensors
  detect a hazard, so better sensors mean faster and safer travel.
- **Exosuit:** first person on foot, with jump jets and climbing.

Every doll can **deploy** the next one, **recall** it, and be **boarded**. Vehicles you leave
behind stay in the world, where they can be damaged, stranded or stolen.

### 2.5 Fully explorable interiors

Each doll has a hull (a low-poly/voxel model defined in Lua) and an interior that is generated
**on demand, sector by sector**, from a deterministic seed:

```
Hull (shape, zones)            e.g. Jump Ship: hangars, foundries, engineering, research, bridge
  └─ Zone (function, layout)   e.g. "Station Hangar 2", "Hydroponics Ring", "Drone Foundry"
       └─ Sector (fixed cube)  generated when the Commander comes near, unloaded when far away
            └─ Rooms, corridors, props (tile grid sized for a 3.6 m exosuit)
```

- Interiors are walkable at Exosuit scale. Hangars are sized for the doll they hold: a Jump Ship
  hangar for a 31 km station is bigger than a city.
- Changes (opened doors, damage, items, intruders) are stored as **deltas** per sector, so a
  144 km ship costs only what the player changed.
- Trams, lifts and teleport pads connect zones. The bridge and other key rooms are hand-authored in Lua.
- **Crew: one human, a ship AI and many drones.** The Commander is the only person aboard. The ship
  AI speaks; maintenance, cargo, survey and security drones keep the dolls running. The interiors
  feel vast and eerie.
- Interiors are not safe. Boarders, parasites carried up from planets and failing systems make
  the dolls places to explore and defend.

---

## 3. Core Loop

```
 Jump into a system
   → survey from the Jump Ship (marvels and signals flagged)
   → deploy a Space Station to a planet, teleport there
   → orbital scan (biomes, weather, settlements, anomalies)
   → deploy a Continental Explorer, take the Drop Ship down
   → cross the continent, scan, pick a site → deploy a Land Explorer
   → scan the region → deploy a Walker → step out in the Exosuit
   → discover: samples, creatures, ruins, artefacts, peoples, trade
   → get out alive, recall the chain, research, upgrade, build
 Jump onward
```

The tension comes from **over-extension**. Every doll you deploy is valuable and exposed. A storm
seen from orbit, a predator pack seen from the Land Explorer, a spore cloud only the Exosuit can
smell: the further down you are, the longer the way back up.

### 3.1 Progression and economy

- **Research and upgrades:** samples, scans and artefacts unlock better sensors, armour, range,
  jump distance and new doll modules.
- **Trading and economy:** markets at native settlements, spacefaring traders and stations, with
  goods, currencies and prices that follow supply, demand and reputation.
- **Outposts and crafting:** build outposts on planets (power, storage, scanners, landing pads);
  craft repairs, consumables and modules from gathered resources.
- **Terrain deformation:** dig, blast and tunnel at Exosuit and Walker scale. The changes persist.
- **Codex (xenopedia):** every discovery is catalogued; you may name planets, species and marvels.

### 3.2 Story: sandbox plus story threads

The galaxy is endless and procedural. A loose overarching mystery runs through it, told through
artefacts, ruins and encounters and written in Lua. Working proposal, for discussion: *the nesting
pattern of your own dolls appears in alien ruins everywhere. Who built the first Jump Ship, and why
does the ship AI remember places you have never been?* Smaller threads attach to factions,
villains and marvels.

---

## 4. Universe and Wonder Generation

Everything is generated from one 64-bit galaxy seed by hierarchical hashing:
`galaxy → sector → system → body → surface region → chunk → object`. The same seed gives the same
universe on every platform (§8.4). Only the player's changes are saved.

### 4.1 Galaxy

- A spiral or elliptical density function; stars are generated per galactic sector on demand.
- The sky is real: the stars you see from a planet are stars you can jump to.
- Nebulae, star clusters and the galactic band are drawn from the same data.

### 4.2 Star systems

**System archetypes:** single star · close binary with circumbinary planets · wide binary (each star
with its own planets) · hierarchical triple · star + brown dwarf · white dwarf with debris disk ·
pulsar with irradiated worlds · black hole with accretion disk · young star with protoplanetary disk ·
red giant swallowing its inner planets · rogue planet with no star.

**A light physics model**, enough to be believable and fast:
- Star mass → luminosity, radius, temperature → colour (black-body table), habitable zone, frost line.
- Orbits are Keplerian and on rails (`a, e, i, Ω, ω, M₀`): the position of any body at any time can
  be computed directly, without an n-body simulation.
- Orbits are spaced by mutual Hill radii, with occasional resonance chains. Moons sit inside the
  Hill sphere, rings inside the Roche limit, Trojans at L4/L5, asteroid belts in gaps, and comets on
  eccentric orbits.

**Planet classes**, from mass, composition, temperature, age and tidal state:
lava · iron · barren rock · desert · terran · ocean · ice · glacier world with subsurface ocean ·
carbon/diamond · super-Earth · mini-Neptune · ice giant · gas giant · hot Jupiter · tidally locked
"eyeball" · shattered world · plus rare "marvel" classes. Each class is a **Lua archetype** with
parameter ranges, a noise-graph recipe, palette rules, and biome, hazard and life tables.

### 4.3 The Wonder Director

Physics makes systems plausible; the Wonder Director makes them memorable. After physical
generation, a curation pass:

1. scores each system for interest (variety, contrast, rarity),
2. places **marvels** from a Lua table. Each marvel has a rarity, prerequisites, a generation effect
   and a scanner signature,
3. guarantees at least one marvel per system and spaces rare ones so they stay rare,
4. shows "unusual signatures" on the galaxy map, so curious players can steer toward novelty.

Example marvels: a ring crossing a moon's orbit, with shepherd gaps · a planet with a polar ring ·
an eyeball world whose life lives only on the twilight band · sky islands on a low-gravity
magnetic world · a glass desert fused by lightning · crystal forests · a shattered planet whose
fragments still hold atmosphere · a moon on a collision course, with a countdown · a pulsar beam
sweeping across a world · a black hole lensing the sky · a dead Dyson swarm · an alien Jump Ship
wreck, nested dolls and all · leviathans drifting in a gas giant · cryovolcanoes throwing ice into
orbit · a permanent super-storm · methane lakes · iron rain · a frozen tsunami · a planet-wide
fungal network · a binary sunset with two shadows · a canyon ten times the size of Valles Marineris.

### 4.4 Rendering a star system (retro, at astronomical scale)

**Scale handling.** Positions are doubles relative to the current reference frame. Each frame is
drawn in **depth slices**: celestial (stars, planets, distant dolls), planetary (the nearby planet
with its atmosphere and rings) and local (everything around the camera). Each slice has its own
near and far planes, and the depth buffer is cleared between slices. Distant bodies are drawn in
*scaled space*: shrunk and moved closer by the same factor, so their angular size stays correct.
This works the same way on desktop OpenGL and WebGL 2.

**Stars:** an emissive sphere, an animated corona billboard and palette-cycled glare, with a minimum
on-screen size and a colour from temperature. Binary stars orbit their barycentre and cast two
coloured lights.

**Planets from space:**
- a cube-sphere mesh with quadtree LOD; the same mesh carries you down to the surface (§4.5);
- a per-planet albedo and height texture, baked at low resolution when the system is generated;
- the atmosphere as a rim-lit shell with a palette-banded sunset gradient;
- clouds as a separate, rotating, dithered shell, and night-side lights on inhabited worlds;
- rings as an annulus with a generated radial density texture (gaps from moon resonances); ring
  shadows on the planet and planet shadows on the ring are computed analytically;
- eclipses from up to four analytic sphere occluders per draw;
- special effects: aurorae, comet tails, pulsar beams, and accretion disks with screen-space lensing.

**Maps:** the system map is a vector-CRT style schematic with orbit lines, logarithmic distances,
time scrubbing and scan overlays. The galaxy map is a point cloud of the real generated stars.

**The sky** is rendered per system into a low-resolution cube map: the real neighbouring stars,
nebulae and the galactic band. The Jump Ship and the stations move across it like moons.

### 4.5 Planet surfaces: seamless from orbit to ground

There are no loading screens between orbit and ground. Generation is multi-resolution and
deterministic, and matches the doll pyramid:
- **Global fields** (on approach, on a coarse cube-sphere grid): tectonic plates, elevation,
  temperature, moisture, biomes, rivers by flow accumulation, and sites for settlements and ruins.
- **Regional detail** (on demand, per quadtree chunk): the archetype's noise graph (ridged,
  domain-warped, terraced, cratered, dunes, erosion-like noise) on top of the global fields.
- **Near field** (Exosuit and Walker range): voxel density for caves, arches and overhangs, meshed
  into flat-shaded low-poly surfaces. This is where terrain deformation lives.
- **Scatter:** rocks and flora placed by blue noise per chunk; fauna populations placed by region
  from the planet's generated ecology.

The details of surface generation are the subject of a later design session.

---

## 5. Danger and Sensors

### 5.1 The sensor pyramid

| Doll | Range | Smallest thing it resolves | Typical finds |
|------|-------|----------------------------|---------------|
| Jump Ship | the system (~100 AU) | ~1,000 km | bodies, fleets, megastructures, stellar flares |
| Space Station | one planet and its moons | ~10 km | continents, storms, biomes, cities, big ruins, volcanism |
| Continental Explorer | ~1,000 km | ~50 m | passes, sinkholes, settlements, megafauna herds, armies |
| Land Explorer | ~30 km | ~5 m | packs, flora fields, caves, patrols, artefact sites, minefields |
| Walker | ~2 km | ~0.5 m | single creatures, traps, small artefacts, entrances |
| Exosuit | ~150 m | ~1 cm | spores, toxins, radiation, gas pockets, micro-swarms, camouflage |

Every hazard has a **signature**: its size, its kind (thermal, bio, EM, seismic, chemical or
exotic) and its stealth. A doll's sensors detect what is big enough and of a kind they cover.
Two rules follow:

- *What kills you is smaller than your sensor's resolution*, so you watch the Exosuit HUD.
- *What kills your vehicle is at least its own size*, so you scan ahead from the doll above.

**Passive and active scanning:** an active ping sees more and farther, and it tells everything
nearby that you are there. Scan data **ages**: creatures move, storms drift, patrols change route.

### 5.2 Sources of danger

- **Terrain and environment:** sinkholes, lava tubes, quicksand, crevasses, unstable cliffs, geysers,
  floods, toxic or crushing atmospheres, radiation, temperature swings at the terminator, lightning
  and electrical storms, meteor showers, tidal surges.
- **Flora:** carnivorous plants, spore clouds, vines that pin a Walker, crystalline growths that
  cut, mobile and mimic plants.
- **Fauna at every scale:** micro-swarms (Exosuit), predators (Walker), kilometre-long megafauna
  (Land Explorer), and rare sky leviathans as big as a Continental Explorer. Ecologies have
  herbivores, predators, territories, migrations and day/night behaviour.
- **Alien artefacts:** ruins of dead civilisations with defence systems, anomalies and puzzles. They
  hold the biggest rewards and cause some of the strangest deaths.
- **Natives:** peoples from the stone age to the edge of spaceflight, with attitudes (curious,
  fearful, territorial, hostile, trading), their own rulers and their own conflicts. You can help,
  trade, avoid or harm them.
- **Spacefaring civilisations:** traders, militarists, isolationists and hive minds, with light
  diplomacy and competition for the same marvels.
- **Real villains:** thieves who steal deployed vehicles and cargo and **board your dolls**,
  tyrants who rule natives by terror, poachers and slavers, claim-jumpers, ancient guardian AIs.

### 5.3 Survival-first answers to danger

- **Avoid:** passive scanning, stealth, route planning around signatures, the autopilot's hazard stops.
- **Escape:** recall to the doll above, emergency teleport from a station, jump jets, sealing sectors.
- **Deter and defend:** Exosuit sidearm and stun tools, Walker countermeasures (flares, decoys,
  sonic and EMP pulses), shields on the big dolls, security drones inside them.
- **Negotiate:** trade, gifts and reputation with natives and factions.

Fights are rare, costly and often lost. Winning usually means not being there.

### 5.4 The Exosuit and death (selectable)

The Exosuit tracks integrity, power, life support, temperature, radiation dose and filter
saturation, with breaches, system failures and emergency protocols (auto-retreat, beacon, sealing
foam). What happens when it finally fails depends on a setting chosen when a game is started:

- **Clone mode:** the Commander wakes in the Jump Ship's clone bay. Deployed dolls stay where they
  were and must be recovered, and they may have been looted in the meantime.
- **Legacy mode (permadeath):** the run ends. The codex of discoveries passes to the next Commander.

---

## 6. Look and Feel: Late-90s PC Retro 3D

- **Internal resolution** of about 480×270, integer-scaled with nearest filtering. Higher in VR, but
  still pixelated.
- **A palette per world** (32–256 colours), derived from the star's colour and the atmosphere, with
  ordered (Bayer) dithering, so every planet has its own mood.
- **Low-poly models** (glTF), small nearest-filtered textures, vertex lighting, coloured fog, light
  coloured by the star. There is no PS1-style vertex jitter by default; an optional setting adds a
  subtle snap.
- **Sprites:** 8-direction billboards for creatures, natives and flora. Procedural creatures are built
  as voxel models and rendered into sprite sheets when they are loaded, which gives classic sprites
  in endless variety.
- **Voxels:** MagicaVoxel models for props, artefacts and vehicle details, and voxel terrain around
  the Exosuit and Walker.
- **Fog and atmosphere** as banded palette gradients; blob shadows; analytic eclipses.
- **Diegetic UI:** each doll has a cockpit or bridge, and the Exosuit HUD is drawn on the visor.
- **Visual art:** procedural generators (textures, palettes, creatures, voxel props) plus placeholder
  models that the project owner can replace with hand-made art over time.
- **Audio:** epic sound effects and ambient space music generated with the **ElevenLabs API**
  (sound-effects and music endpoints). The prompts are kept in the repository so every sound can be
  regenerated. Playback has positional audio and crossfading music layers per situation (deep space,
  orbit, surface, danger, discovery).

---

## 7. Platforms and Controls

| Platform | Build | Input |
|----------|-------|-------|
| Windows / Linux / macOS | native, SDL3 + OpenGL 3.3 core | keyboard + mouse, gamepad |
| Web | Emscripten, WebGL 2 | keyboard + mouse, gamepad; **touch on mobile** (virtual stick, look-drag, context buttons, switched on automatically on touch devices) |
| WebXR | same web build, "Enter VR" button | XR controllers; snap turn, teleport or smooth locomotion, comfort vignette; HUD on the visor |

The web build is published to GitHub Pages from `main`.

The Fukuruma moment the whole design aims at: standing in VR in a 3.6 m exosuit beside a 72 m
walker, beneath a 1.44 km Land Explorer, in the shadow of a 6.7 km Continental Explorer, while the
station and the Jump Ship cross the sky like moons.

---

## 8. Technical Concept (summary; details in the implementation plan)

### 8.1 Engine and game split

- **Core engine (C11):** platform (SDL3), renderer (the shared subset of OpenGL 3.3 core,
  OpenGL ES 3.0 and WebGL 2), audio, input mapping, virtual file system, asset loaders (glTF,
  MagicaVoxel, PNG, OGG), reference frames and scale, procedural generation kernels (hashing, noise
  graphs, terrain meshing, voxels), interior sector streaming, collision, entity storage, job system,
  save system, Lua bindings.
- **Game (Lua 5.4):** doll definitions, generation recipes and archetypes, the Wonder Director,
  marvels, ecology, AI behaviours, factions, economy, research, crafting, missions, story threads,
  UI layout, codex text, mod API.
- Hot loops stay in C. *What* to generate and *how the game plays* is Lua.

### 8.2 Assets beside the binary

```
fukuruma(.exe)
data/       scripts/ shaders/ textures/ models/ voxels/ sprites/ sounds/ music/ fonts/ palettes/
mods/       one folder per mod, overlaid on data/ in load order
```

On the web, the same `data/` folder is packaged as a separate data file next to the `.wasm` and can
be swapped without rebuilding. Code (C, Lua, shaders, tools) is MIT. Art (textures, models, voxels,
sprites, sounds, music) is CC BY 4.0.

### 8.3 Quality

- An OpenSpec change proposal for every feature. Specs describe behaviour.
- Unit tests for C and Lua, with **at least 95% line coverage** enforced in CI.
- **Automated game tests:** headless, deterministic Lua scenarios that drive inputs, assert game
  state and compare screenshots against reference images. The web build is tested in a browser,
  including touch mode.
- Ponytail rules (`AGENTS.md`) for every agent working on the code: the smallest complete change.

### 8.4 Determinism and co-op readiness

- Generation gives the same universe on x86, ARM and WebAssembly. It uses integer hashing, no fused
  multiply-add, and in-house approximations of the few transcendental functions it needs. CI compares
  generation hashes across all platforms.
- **Co-op comes later**, so the simulation is built for it now at little cost: state changes go
  through serialisable commands; the simulation runs in fixed, deterministic steps; entities have
  stable IDs; the Commander is an entity, not a global. No networking code until co-op is scheduled.

---

## 9. Out of Scope for 1.0

Networking and co-op (prepared for, not built) · voice acting beyond the ship AI ·
a story campaign with an ending · VR on native desktop (OpenXR) · console ports.

---

## 10. Decisions (answers to the clarifying questions, 2026-11-26)

| # | Question | Decision |
|---|----------|----------|
| 1 | Scale | **Compressed ×100 steps**: ×20 steps are heights, ×100 steps are volumes. Exosuit 3.6 m, Walker 72 m, Land Explorer 1.44 km, Continental Explorer ≈ 6.7 km, Station ≈ 31 km, Jump Ship 144 km. |
| 2 | Planets | **Seamless** from orbit to ground. |
| 3 | Combat | **Survival first**: scan, avoid, flee; limited defensive tools. |
| 4 | Failure | **Selectable** at game start: Clone mode or Legacy (permadeath) mode. |
| 5 | Story | **Sandbox plus story threads** (an overarching mystery told through artefacts). |
| 6 | Multiplayer | **Co-op later**: single-player first; deterministic, command-based simulation from day one. |
| 7 | Crew | **The Commander, a ship AI and drones.** No human NPC crew. |
| 8 | Scope | **All of:** research and upgrades, trading and economy, outposts and crafting, terrain deformation. |
| 9 | Retro look | **Late-90s PC** (Quake, Daggerfall, Outcast era). |
| 10 | Art and audio | **Audio generated with the ElevenLabs API** (epic sound effects, ambient space music). Visual art was not specified; the default is procedural generators plus replaceable placeholder art. |
