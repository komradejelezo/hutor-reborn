# hutor-reborn
Atmospheric Slavic dark fantasy RPG built with Godot 4.6

Open `HutorReborn/project.godot` in Godot 4.6 and press F5 to play «Кривая Сосна». Stage 2 documentation: `HutorReborn/docs/KRIVAYA_SOSNA.md`.

The earlier expansion grew the starting area to 2624 × 2176 px (2.003× its previous area), with expanded yards and forest trails and pixel-preserving seamless terrain. That stage's documentation and validation: [KRIVAYA_SOSNA_EXPANDED.md](HutorReborn/docs/KRIVAYA_SOSNA_EXPANDED.md).

Stage 3.1 refines the existing surfaces without changing the layout or mechanics: nonperiodic source-pixel terrain, irregular road transitions and saved object ground masks. Audit, before/after screenshots and validation: [STAGE31_SURFACES.md](HutorReborn/docs/STAGE31_SURFACES.md).

Stage 3.2 improves the existing forest, the landmark's framing and all five courtyards while retaining Stage 3.1 terrain and gameplay. Resources, screenshots, physical/depth checks and performance samples: [STAGE32_ENVIRONMENT.md](HutorReborn/docs/STAGE32_ENVIRONMENT.md).

Stage 3.3 polishes the existing evening lights and world-space mist, preserves the approved environment and gameplay, and verifies character readability, routes and camera behavior. Screenshots, checks and measured performance: [STAGE33_LIGHTING.md](HutorReborn/docs/STAGE33_LIGHTING.md).

Stage 4.1 adds reusable data-driven conversations with portraits, choices, typewriter text and a custom dark fantasy UI. F5 retains the existing game; open `HutorReborn/scenes/demo/dialogue_demo.tscn` and press F6 for the optional demonstration. Architecture, authoring guide and validation: [STAGE41_DIALOGUE.md](HutorReborn/docs/STAGE41_DIALOGUE.md).

Stage 4.2 updates the village to seven buildings, adding a modular roadside inn and an abandoned woodland house while retaining the five original building anchors and the crooked pine. Current map: 2976 × 2560 px, with preserved 3.1 terrain, 3.3 atmosphere and unchanged 4.1 dialogue code. Placement, resources, screenshots and checks: [STAGE42_VILLAGE.md](HutorReborn/docs/STAGE42_VILLAGE.md).

Stage 4.3 adds nine resource-configured residents, shared obstacle-aware navigation, cyclic routines, original walk/work frames and E conversations through the existing dialogue UI. The approved Stage 4.2 map and Hans remain unchanged. Idle poses are explicitly static fallbacks; elder art and resident portraits are provisional/pending. Architecture, authoring guide, asset status and validation: [STAGE43_RESIDENTS.md](HutorReborn/docs/STAGE43_RESIDENTS.md).

Stage 4.4 adds three playable interiors: the inn, elder's home and herbalist's modest shared home. E at their doors fades between cached scenes, carries the same Hans and eligible residents, restores the outside camera and uses a 1.3x camera indoors. The village scene, original art, Hans and dialogue UI remain intact. Architecture, authoring guide, screenshots and validation: [STAGE44_INTERIORS.md](HutorReborn/docs/STAGE44_INTERIORS.md).

Stage 4.5 adds three compact interiors through the existing registry: the woodcutter family's home, old man's home and communal storehouse. All 4.4 rooms and runtime scripts remain byte-identical. Existing resident IDs have prepared household/access points; full scheduling remains a later stage. Scenes, resources, tests and screenshots: [STAGE45_REMAINING_INTERIORS.md](HutorReborn/docs/STAGE45_REMAINING_INTERIORS.md).
