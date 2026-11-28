# Fukuruma — Game Concept

> Status: **v0.5**. Updated with the answers to the ten clarifying questions, the follow-ups on
> graphics and game feel, and the first-person rule: everything is seen through the Commander's eyes
> (see §10, *Decisions*).
> The build plan is in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md).

Fukuruma is a space exploration game about **wonder** and **scale**, built on modern real-time
rendering and shown through a retro low-resolution filter. You command a
moon-sized Jump Ship. It carries space stations, which carry mountain-sized explorers, which carry
walking cities, which carry giant walkers, which carry you: the Commander in an environmental
exosuit, the last and smallest doll. Every doll can be entered, walked through and deployed.
Every planet is worth going down to, and any planet can kill you. You see all of it through the
Commander's own eyes: from the Exosuit's helmet, or from the seat at a doll's controls.

---

## 1. Pillars

1. **Wonder of exploration.** Every star system has at least one thing you have never seen before.
   Generation is physically inspired and artistically directed: a "Wonder Director" keeps the
   galaxy surprising.
2. **Fukuruma (the nesting doll).** Seven nested scales. Each doll is a vehicle you fly, drive or walk,
   and you can explore every one of them inside. Going *down* the chain brings you closer to
   discoveries and to danger. Going *up* the chain is how you survive.
3. **Through the Commander's eyes.** The game is always first person. You walk inside the Exosuit
   and steer every doll from its cockpit or bridge: the 72 m Walker from a cabin high above the
   ground, the 144 km Jump Ship from its bridge. An outside view exists, but only to look around and
   get your bearings; you cannot walk or steer from it.
4. **Real danger, read through sensors.** You never walk in blind, but every sensor has a range and
   a resolution. Big vehicles see big threats and miss small ones. The exosuit sees the things that
   kill people.
5. **Survive, don't conquer.** Scanning, avoiding, outrunning and outsmarting come first. Weapons are
   few, defensive and costly to use.
6. **Modern rendering, retro resolution.** Detailed models, physically based lighting and shadows,
   and realistic fire, water, fog and clouds, rendered at a deliberately low resolution and scaled
   up with sharp pixels. Only the resolution is retro. It is a style and a budget: rendering a
   sixteenth of the pixels pays for the expensive effects.
7. **Weight and juice.** The dolls move with believable mass, animations have weight, and every action
   is answered with sound, light, particles, camera motion and rumble. A Walker's footstep shakes the
   ground under the Exosuit.
8. **Open and moddable.** A C engine with the game itself in Lua. Assets, scripts and shaders live in
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
| — | **Drop Ship** | outside the chain | ≈ 12 km | carries a Continental Explorer between a station and the sky, and the Commander between dolls |

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
- **Drop Ship (≈ 12 km).** A ball big enough to hold a Continental Explorer: it carries one from a station down to
  the sky of its planet and sets it down there ("board a drop ship to the planet"), takes one back aboard, and flies
  the Commander between any two dolls where there is no teleporter. (Owner's decision, 2026-11-28: it was 100 m,
  which looked absurd next to what it carries.)

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
sees the engine switch detail levels. They see the next doll being deployed, through the cockpit
window or on the bridge screens.

### 2.4 Movement and travel

Every doll is steered by the Commander in person, from the seat at its controls (§2.6). Autopilot lets
the Commander leave the seat and walk around inside while the doll travels.

- **Jump Ship:** jumps between systems; moves on rails inside a system.
- **Teleport network:** the Commander teleports between the Jump Ship and every deployed station.
- **Space Station:** fixed in orbit once deployed; can be recalled.
- **Drop Ship:** flies from station to surface and between dolls.
- **Continental Explorer:** flies across the planet; autopilot with time compression.
- **Land Explorer / Walker:** drive or walk; autopilot to waypoints. Autopilot stops when the sensors
  detect a hazard, so better sensors mean faster and safer travel.
- **Exosuit:** first person on foot, with jump jets and climbing.

Every doll can **deploy** the next one, **recall** it, and be **boarded**. This is the nesting doll the
game is named after: the next doll down stands docked in its parent's hangar, and the Commander
boards it on foot, out of the bridge, down to the hangar, up the ramp into the docked doll, along
its corridors to its bridge, and deploys it from there, leaving the parent behind (decided
2026-11-27). A quick "go to the controls" shortcut plays the walk as a short first-person sequence. Vehicles you
leave behind stay in the world, where they can be damaged, stranded or stolen.

### 2.5 Fully explorable interiors

Each doll has a hull (a detailed model assembled from parts by a Lua grammar) and an interior that is generated
**on demand, sector by sector**, from a deterministic seed:

```
Hull (shape, zones)            e.g. Jump Ship: hangars, foundries, engineering, research, bridge
  └─ Zone (function, layout)   e.g. "Station Hangar 2", "Hydroponics Ring", "Drone Foundry"
       └─ Sector (fixed cube)  generated when the Commander comes near, unloaded when far away
            └─ Rooms, corridors, props (tile grid sized for people: the Commander walks inside as a human)
```

- Interiors are made for people: the Commander walks every doll's rooms, corridors and decks as a
  human (1.8 m), and puts the Exosuit on at a suit bay or airlock to go out onto a planet (decided
  2026-11-27). Hangars are sized for the doll they hold: a Jump Ship hangar for a 31 km station is
  bigger than a city.
- Changes (opened doors, damage, items, intruders) are stored as **deltas** per sector, so a
  144 km ship costs only what the player changed.
- Trams, lifts and teleport pads connect zones. The bridge and other key rooms are hand-authored in Lua.
- **Crew: one human, a ship AI and many drones.** The Commander is the only person aboard. The ship
  AI speaks; maintenance, cargo, survey and security drones keep the dolls running. The interiors
  feel vast and eerie.
- Interiors are not safe. Boarders, parasites carried up from planets and failing systems make
  the dolls places to explore and defend.

#### Why the Commander walks the dolls (decided 2026-11-28)

The dolls are homes and machines, not corridors to cross. The Commander is a person who has to eat, sleep and wash,
and the dolls only keep going if someone looks after them. Every doll except the Exosuit holds what a person needs to
live. The bigger the doll, the more it holds:

| Room | In | What it is for |
|------|----|----------------|
| Galley | every doll but the Exosuit | Eat: hunger to zero. Meals come from the doll's stores, then from rations grown in a biotope. |
| Quarters | every doll (more the bigger it is) | Sleep: fatigue to zero. |
| Bath | every doll | Wash: the grime gathered outside (faster in toxins) to zero. |
| Med bay | every doll | Treatment: the radiation dose cleared and the suit mended. |
| Engine room | every doll | Maintain: engine wear to zero. Wear grows while the doll moves; above half it costs top speed. |
| Life support | from 1 km | Service: the air plant wears while the Commander is aboard; when it is spent, the doll no longer restores the suit. |
| Workshop, lab | from 1 km | The workshop and research menus at a bench. |
| Drone bay, cargo deck | from 1 km / every doll | Drones; what boarders come for. |
| Biotope | from 6 km (Drop Ship, Continental Explorer, station, Jump Ship) | A tall hall of soil beds, grow lights, fruit trees and a water channel. Its crop ripens and is harvested into rations. |
| Suit bay, clone bay | where the Exosuit is carried / the Jump Ship | Out onto a planet; back after a death (Clone mode). |

- **Needs.** Hunger fills in about 40 minutes and fatigue in about an hour. The visor warns when they near full. A
  starving or exhausted Commander stops mending aboard and slowly wears down outside. Long expeditions therefore come
  back to a doll, and a doll far from home needs its galley stocked and its biotope tended.
- **Upkeep.** The cockpit screens show each doll's engine and air state. A worn doll is slow, and a doll with spent
  life support is no refuge. Walking down to the engine room is part of travelling.
- **Rooms are detailed and streamed.** Each room type has its own furniture and lights: tables and a serving counter,
  bunks and lockers, showers, med beds under scanners, a reactor in glowing rings, crop beds under grow lights. A
  Continental Explorer, a station or the Jump Ship has more rooms than are kept in memory. Only the rooms within
  about 40 m of the Commander are built, a couple per frame. Rooms beyond 70 m are let go. The corridor and the big
  plain hangars always stay.

### 2.6 The Commander's view

The game is seen **only through the Commander's eyes**. There is no chase camera.

- **On foot inside a doll:** the Commander's own eyes, at human height, in rooms made for people.
- **On foot outside:** the view from inside the Exosuit's helmet, with the visor HUD, the suit's arms and
  hands, and its legs and feet when you look down. The head bobs and sways with the suit's mass.
- **At the controls:** every doll has a cockpit or bridge with a seat, windows or a canopy, and
  instruments. The Commander sits there and looks out: the Walker's cabin sways 60 m above the ground
  with every step; the Land Explorer's bridge looks down over a kilometre of moving machinery; the
  Continental Explorer, the Space Station and the Jump Ship are flown from bridges whose big screens
  show what the windows cannot. The Commander's hands work the sticks, levers and switches.
- **Looking around:** the head turns freely within the limits of the seat (and the helmet) while the
  doll keeps its course: steering and looking are separate controls.
- **Screens instead of camera tricks:** cockpit screens show the map, the sensors, the doll's status
  and its external cameras. Scan results are drawn onto the windows and the visor as augmented-reality
  markings (§5).
- **The outside view, for orientation only:** a button switches to the doll's survey drone, which
  circles the current doll (or the Exosuit) at a distance scaled to its size, so you can see where
  you are, what surrounds you and where the next doll stands. You can turn and zoom the view and mark
  a waypoint, but you cannot walk, steer or act from it: the Exosuit stands still, a doll holds its
  course (or its autopilot keeps flying), and every control except "back to the Commander's eyes" is
  inactive. The view is a drone
  feed, with its range limits and a little signal noise, and it closes when the Commander takes
  damage.
- **Deploying and docking** are watched from the cockpit windows, on the bridge screens, or with the
  outside view.
- **Comfort:** first-person motion in swaying machines needs care: head-bob and cockpit-sway
  strength, field of view, a horizon-steady option that keeps the horizon level while the cabin
  rocks, and a vignette while turning are all in the comfort settings. In VR the head is never moved
  by effects (§6.5).

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
parameter ranges, a noise-graph recipe, material and colour-grading rules, and biome, hazard and life tables.

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

### 4.4 Rendering a star system at astronomical scale

**Scale handling.** Positions are doubles relative to the current reference frame. Each frame is
drawn in **depth slices**: celestial (stars, planets, distant dolls), planetary (the nearby planet
with its atmosphere and rings) and local (everything around the camera). Each slice has its own
near and far planes, and the depth buffer is cleared between slices. Distant bodies are drawn in
*scaled space*: shrunk and moved closer by the same factor, so their angular size stays correct.
This works the same way on desktop OpenGL and WebGL 2.

**Stars:** an HDR emissive sphere with animated convection cells, prominences and a corona, with
bloom and lens flare driven by the star's real brightness and a colour from its temperature.
Exposure adapts, so a star seen from a planet's night side, from orbit and from deep space each
looks right. Binary stars orbit their barycentre and cast two coloured lights and two shadows.

**Planets from space:**
- a cube-sphere mesh with quadtree LOD; the same mesh carries you down to the surface (§4.5);
- physically based surface materials (rock, sand, ice, vegetation, ocean) from the planet's
  generated fields, with specular glints on oceans and ice;
- **physically based atmospheric scattering** (Rayleigh, Mie and absorption, tuned to each
  atmosphere's chemistry): blue, orange, green or violet skies and sunsets that follow from the
  planet's data, the same model seen from orbit and from the ground;
- **volumetric clouds** driven by the planet's climate fields, casting shadows on the ground; from far
  away they turn into a cloud layer baked from the same data. City lights on inhabited night sides;
- rings as an annulus with a generated radial density texture (gaps from moon resonances),
  forward-scattering sunlight; ring shadows on the planet and planet shadows on the ring;
- eclipses and planetshine (sunlight reflected from a planet lights the dolls in orbit);
- special effects: aurorae, comet tails and comas, pulsar beams, and accretion disks with
  gravitational lensing.

**Maps:** the system map is a holographic schematic with orbit lines, logarithmic distances,
time scrubbing and scan overlays. The galaxy map is a point cloud of the real generated stars.

**The sky** is rendered per system into an HDR cube map: the real neighbouring stars, volumetric
nebulae and the galactic band. It also lights the scene (image-based lighting). The Jump Ship and
the stations move across it like moons.

### 4.5 Planet surfaces: seamless from orbit to ground

There are no loading screens between orbit and ground. Generation is multi-resolution and
deterministic, and matches the doll pyramid:
- **Global fields** (on approach, on a coarse cube-sphere grid): tectonic plates, elevation,
  temperature, moisture, biomes, rivers by flow accumulation, and sites for settlements and ruins.
- **Regional detail** (on demand, per quadtree chunk): the archetype's noise graph (ridged,
  domain-warped, terraced, cratered, dunes, erosion-like noise) on top of the global fields.
- **Near field** (Exosuit and Walker range): voxel density for caves, arches and overhangs, meshed
  into smooth surfaces with triplanar physically based materials (rock strata, soil, sand, ice,
  crystal), detail normal maps, and wetness, snow and dust layers that follow the weather. This is
  where terrain deformation lives.
- **Scatter:** detailed, instanced rocks and flora placed by blue noise per chunk, swaying in the
  wind, with impostors in the distance; fauna populations placed by region from the planet's
  generated ecology.

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

- *What kills you is smaller than your sensor's resolution*, so you watch the Exosuit's visor HUD.
- *What kills your vehicle is at least its own size*, so you scan ahead from the doll above.

**Passive and active scanning:** an active ping sees more and farther, and it tells everything
nearby that you are there. Scan data **ages**: creatures move, storms drift, patrols change route.

**Seeing danger:** you look at the world through windows, the visor and cockpit screens, and many
hazards are visible if you look: spore clouds and toxic gas drift as
volumetric fog, lava shimmers with heat haze, a dust storm swallows the light. Others are invisible
(radiation, a camouflaged predator, a thin crust over a sinkhole), and only sensors reveal them.

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

## 6. Look and Feel: Modern Rendering Behind a Retro Filter

Everything in the world is modern: detailed geometry, physically based materials, realistic light,
shadows, volumes, water, fire and animation. **Only the resolution is retro.** The image is rendered
at a low internal resolution and scaled up with sharp, square pixels. The pixels are big, and what
they show is rich.

### 6.1 The retro filter

- **Internal resolution presets:** *Classic* 480×270, *Sharp* 640×360, *Fine* 960×540, scaled to the
  window by an integer factor with nearest filtering (a sharp-bilinear filter for screens that are
  not a clean multiple). The whole HDR pipeline runs at the internal resolution.
- **Stable pixels:** detailed geometry at a low resolution flickers when the camera moves. The
  renderer prevents that with 2×2 supersampling into the internal resolution on capable hardware,
  or temporal anti-aliasing on weaker hardware, and with shadow maps snapped to their texel grid.
- **Optional stylisation:** subtle ordered dithering (on by default, it also hides colour banding)
  and an optional *palette mode* that quantises each world to its own colour palette, for players
  who want a stronger retro look.
- **UI:** pixel fonts and widgets at a multiple of the internal resolution, with an accessibility
  option to draw text at the native resolution.
- **VR:** a higher internal resolution per eye (still visibly pixelated) for comfort and readability.

**Why it saves time:** 480×270 is one sixteenth of the pixels of 1080p. Everything that costs per
pixel (lighting, shadow filtering, ambient occlusion, volumetric fog, ray-marched clouds,
reflections, particles) costs a sixteenth. Geometry detail is chosen by how many *internal* pixels
an object covers, so distant detail is dropped early. That budget is what makes realistic effects
possible on phones and in the browser.

### 6.2 Graphics detail levels

The game has four detail levels, **Low, Medium, High and Ultra**, plus **Custom**. They are chosen in
the in-game menu (*Settings → Graphics*) and take effect immediately, without a restart, while the
scene stays visible behind the menu. The first start picks a level for the device (phone, laptop,
desktop, VR headset); the choice is saved.

The levels differ **mostly in light, shadows and effects, and only a little in models**. Every
level shows the same detailed models; Low only drops distant detail a bit earlier.

| Setting | Low | Medium | High | Ultra |
|---------|-----|--------|------|-------|
| Model detail | slightly earlier LOD switch | almost full | full | full |
| Shadows | one cascade, hard edges | 3 cascades, soft | 4 cascades + far cascade for dolls, local light shadows | wider soft penumbras, contact shadows, more shadowed lights |
| Lighting | star + sky light, few local lights | more local lights | many local lights, planetshine | many local lights, planetshine, bounce light approximation |
| Ambient occlusion | none | basic | full | full, higher quality |
| Clouds | painted cloud layer | volumetric, few steps | volumetric | volumetric, full resolution, more steps |
| Fog and light shafts | simple height fog | coarse volumetric fog | volumetric fog with light shafts | finer volumetric fog |
| Water | normal-mapped surface | waves | waves, foam, reflections | + refraction and caustics |
| Particles | 25% | 50% | 100% | 100%, lit and casting into the fog |
| Post-processing | bloom, tone mapping, colour grading | + automatic exposure | + optional motion blur and depth of field | + lens flares, heat haze |
| Anti-aliasing | none (pure pixels) | temporal | temporal | 2×2 supersampling |

Independent of the level, the menu also offers the internal resolution (Classic, Sharp, Fine), the
retro options (dithering, palette mode) and the comfort options. *Custom* unlocks every row
separately.

### 6.3 Rendering

- **3D objects, sprites and voxels, the modern way:** detailed 3D models for everything solid;
  sprites for particles, flipbook effects and distant impostors of trees, rocks and herds; voxels for
  deformable terrain, caves and destructible props, meshed into smooth surfaces.
- **Detailed models and materials:** glTF models with physically based materials (base colour,
  normal, roughness, metalness, occlusion, emission), detail textures, and triplanar materials for
  terrain. Procedural hulls, creatures and props get the same material system.
- **Lighting:** HDR, physically based shading, image-based lighting from the real sky, automatic
  exposure, a filmic tone curve and per-world colour grading (each world has its own mood).
  Many local lights: cockpit screens, floodlights, bioluminescence, fire, muzzle flashes.
- **Shadows:** soft, filtered cascaded shadow maps from the star (two sets for binary stars), a
  far cascade for doll-sized shadows (a 6.7 km Continental Explorer darkens the landscape it flies
  over), shadows from local lights, contact shadows and ambient occlusion. Eclipses, ring shadows
  and cloud shadows on the ground.
- **Atmosphere and sky:** physically based scattering for every atmosphere composition, aerial
  perspective, sunrises and sunsets, starry night skies, aurorae.
- **Clouds:** ray-marched volumetric clouds from the planet's weather, with storms, anvils and
  lightning lit from inside.
- **Fog and volumes:** volumetric height fog, light shafts through clouds, forests, hangar doors and
  ruins; local volumes for smoke, dust, steam, spores and toxic gas, lit and shadowed like everything else.
- **Water:** oceans with wind-driven waves, swell and foam; rivers with flow and waterfalls with mist;
  reflections and refraction, depth colour, caustics, an underwater mode with its own fog; surfaces
  that get wet in rain and dry again.
- **Fire, smoke and explosions:** particle fire with real light emission and flicker, heat haze,
  smoke that joins the volumetric fog, embers and sparks, scorch decals. Fire can spread through
  dry vegetation as a hazard.
- **Weather and particles:** rain, snow, hail, sandstorms, ash fall, meteor streaks, dust kicked up by
  every step and landing; decals for footprints, tracks and scorch marks.
- **Post-processing:** bloom, lens flares from bright light sources, motion blur and depth of field
  (subtle and optional), heat distortion, damage effects on the Exosuit visor.

### 6.4 Animation

- **Skeletal animation** from glTF, with blending, layered state machines and root motion.
- **Procedural locomotion and IK:** the Walker and Land Explorer plant their feet on real terrain
  and adjust their bodies over slopes and rubble. Generated creatures get procedural gaits from their
  body plan (two, four, six or more legs, slithering, flying, drifting).
- **Secondary motion:** cables, antennae, tails, fins, foliage and cloth react with springs and
  simple physics; creatures fall as ragdolls; dolls rock on their suspension.
- **Mechanical sequences:** deploying, docking and boarding play as choreographed machine
  animations: hangar doors, clamps, ramps, gantries, unfolding legs. They are timed in Lua and
  carry their sounds, lights and particles.
- **The Commander** has first-person arms and hands for tools, climbing and controls: they grip the
  Exosuit's tools, pull levers and push sticks in the cockpits in step with the player's input, and
  the Exosuit's legs and feet are animated when you look down.

### 6.5 Game feel ("juice")

The aim is a realistic kind of juice: mass and physical response, not cartoon exaggeration.

- **Mass and scale you can feel:** every doll has acceleration, braking and turning curves for its
  mass, felt from inside: the Commander's head lags and settles, the cabin sways and pitches, the
  instruments rattle, loose cables swing, dust and rain run over the canopy. A Walker's footstep jolts
  its cabin and, outside, shakes the Exosuit's view and throws up dust; a Land Explorer's step can be
  felt kilometres away; the Continental Explorer's engines rumble in the chest (low-frequency audio
  and controller rumble).
- **Every action is answered:** each command is answered within one frame by a sound, a light, a
  particle effect, a camera response and a haptic pulse, scaled to its importance.
- **Anticipation and follow-through:** deploy sequences build up (warning lights, alarms, unlocking
  clamps) before the release, and settle after it (sway, dust, servo whine).
- **Impacts:** brief hit-pause on heavy impacts, camera kick, debris, sparks and decals; damage you can
  see on hulls and on the visor.
- **Discovery moments:** a new marvel or species gets a music swell, a codex chime, a highlight on the
  visor or window and a close-up on a cockpit screen. The view itself is never taken from the player.
- **UI with springs and easing**, a visor HUD that glitches when the suit is damaged, and readouts
  that react to what the sensors see.
- **Haptics** on gamepads, phones (vibration) and XR controllers.
- **Comfort first:** camera shake, flashes and motion blur have intensity settings; in VR the camera
  is never moved by effects, and the world and controllers shake instead.

All of this is **presentation**: it reacts to simulation events but never changes the simulation,
so the game stays deterministic (§8.4).

### 6.6 Diegetic UI, art and audio

- **Diegetic UI:** each doll has a cockpit or bridge whose instruments and screens are the interface,
  and the Exosuit HUD is drawn on the visor. Menus (settings, codex, map) appear on a cockpit screen
  or as a visor overlay; only the pause menu is a plain overlay.
- **Visual art:** procedural generators build detailed content (hull parts and greebles from a
  grammar, creature bodies from body plans, materials from noise), together with free CC0 material
  and sky libraries and placeholder models that the project owner can replace with hand-made art.
- **Audio:** epic sound effects and ambient space music generated with the **ElevenLabs API**
  (sound-effects and music endpoints). The prompts are kept in the repository so every sound can be
  regenerated. Playback has positional audio with distance filtering, reverb per space (hangar,
  cave, open plain, helmet), and crossfading music layers per situation (deep space, orbit, surface,
  danger, discovery).

---

## 7. Platforms and Controls

| Platform | Build | Input |
|----------|-------|-------|
| Windows / Linux / macOS | native, SDL3 + OpenGL 3.3 core | keyboard + mouse (mouse look), gamepad (left stick moves or steers, right stick looks) |
| Web | Emscripten, WebGL 2 | keyboard + mouse (pointer lock for mouse look), gamepad; **touch on mobile** (virtual stick, look-drag, context buttons, switched on automatically on touch devices) |
| WebXR | same web build, "Enter VR" button | XR controllers; snap turn, teleport or smooth locomotion, comfort vignette; HUD on the visor |

Every platform has one button for the outside view (for example V, the gamepad's View button, or a
touch button) and one for taking or leaving the controls of a doll.

The web build is published to GitHub Pages from `main`.

The Fukuruma moment the whole design aims at: standing in VR in a 3.6 m exosuit beside a 72 m
walker, beneath a 1.44 km Land Explorer, in the shadow of a 6.7 km Continental Explorer, while the
station and the Jump Ship cross the sky like moons.

---

## 8. Technical Concept (summary; details in the implementation plan)

### 8.1 Engine and game split

- **Core engine (C11):** platform (SDL3); a physically based HDR renderer at low internal resolution
  (shadows, atmosphere, volumetric clouds and fog, water, particles, post-processing) on the shared
  subset of OpenGL 3.3 core, OpenGL ES 3.0 and WebGL 2; skeletal and procedural animation; physics
  (characters, vehicles, rigid bodies, ragdolls); the presentation layer for game feel; audio, input
  mapping, virtual file system, asset loaders (glTF, PNG/JPEG, OGG); reference frames and scale;
  procedural generation kernels (hashing, noise graphs, terrain meshing, voxels, hull and creature
  meshes); interior sector streaming; entity storage; job system; save system; Lua bindings.
- **Game (Lua 5.4):** doll definitions, generation recipes and archetypes, the Wonder Director,
  marvels, ecology, AI behaviours, factions, economy, research, crafting, missions, story threads,
  UI layout, codex text, mod API.
- Hot loops stay in C. *What* to generate and *how the game plays* is Lua.

### 8.2 Assets beside the binary

```
fukuruma(.exe)
data/       scripts/ shaders/ textures/ materials/ models/ animations/ sprites/ luts/ fonts/ sounds/ music/
mods/       one folder per mod, overlaid on data/ in load order
```

On the web, the same `data/` folder is packaged as a separate data file next to the `.wasm` and can
be swapped without rebuilding. Code (C, Lua, shaders, tools) is MIT. Art (textures, materials,
models, animations, sprites, colour-grading tables, fonts, sounds, music) is CC BY 4.0, except audio generated with
ElevenLabs, which ships only as part of the game under ElevenLabs' terms (`LICENSE-ASSETS.md`).

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
- **Presentation is outside the simulation:** rendering, animation blending, particles, camera feel,
  hit-pause and haptics react to simulation events but never change simulation state. Physics that
  affects gameplay (characters, vehicles, debris you can collide with) runs in the deterministic
  simulation; purely visual motion (foliage, cables, sparks) runs in presentation.

---

## 9. Out of Scope for 1.0

Networking and co-op (prepared for, not built) · voice acting beyond the ship AI ·
a story campaign with an ending · VR on native desktop (OpenXR) · console ports.

---

## 10. Decisions (answers to the clarifying questions and follow-ups, 2026-11-26)

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
| 9 | Retro look | **Only the resolution is retro** (follow-up, 2026-11-26; replaces the first answer, "late-90s PC"). Modern technology underneath: detailed models, realistic lighting and shadows, realistic fire, water, fog and clouds, good animation and a realistically juicy feel, all shown through a low-resolution filter that also saves rendering time. |
| 10 | Art and audio | **Audio generated with the ElevenLabs API** (epic sound effects, ambient space music). Visual art was not specified; the default is procedural generators, CC0 material libraries and replaceable placeholder models. |
| 11 | Detail levels | **Low, Medium, High, Ultra and Custom**, switched live in the in-game menu (follow-up, 2026-11-26). The levels differ mostly in light, shadows and effects, only a little in model detail (§6.2). |
| 12 | View | **First person from the Commander's perspective, always** (follow-up, 2026-11-26): from the Exosuit's helmet on foot, from the seat at the controls in every doll. All walking and steering happens from inside. An outside view exists only for orientation and allows no movement or actions (§2.6). |
