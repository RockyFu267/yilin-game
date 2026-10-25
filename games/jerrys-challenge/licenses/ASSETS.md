# Asset credits and license record

The character animation sheets, terrain atlas, and fruit sprites in `assets/`
are from **Pixel Adventure 1**, by **Pixel Frog**.

Source: https://pixelfrog-assets.itch.io/pixel-adventure-1
License: **Creative Commons Zero v1.0 Universal (CC0 1.0)**
License text: https://creativecommons.org/publicdomain/zero/1.0/legalcode
Verified: 2026-10-23.

The author's source page explicitly permits distribution, remixing, adaptation,
and commercial use without required attribution. The original archive contains
no separate license file, so this record identifies the source and license.
The four original platformer character sets, terrain and fruits use this CC0 pack.

Two additional Tom and Jerry fan-character sprite sets were created with the
built-in imagegen tool for the user's private family demo on 2026-10-23. Their
sprites live in `assets/characters/Tom Cat/` and `Jerry Mouse/`. They are not
part of Pixel Adventure and are not described as CC0 or original character IP.
Generation prompt and import steps are recorded in the game's character docs.

The retired 0.2.0 forest background `assets/world/forest-clearing.png` was generated
for this project with the built-in imagegen tool on 2026-10-23, without third-party
reference image inputs. Prompt and provenance are recorded in the game's design
documents (`美术与合作方向.md`). It is not a Terraria or Minecraft asset.
It is no longer used at runtime and is excluded from 0.2.1 exports. The current
background is drawn in code on a 3x pixel grid to match the existing sprites.

Silkscreen font: Copyright 2001 The Silkscreen Project Authors. Distributed under
the SIL Open Font License 1.1; see Silkscreen-OFL.txt. Downloaded from the Google
Fonts repository: https://github.com/google/fonts/tree/main/ofl/silkscreen .

Game UI, scenery geometry, puzzle logic and procedural notification sounds are
created for this project. No downloaded audio is used. Chinese text uses the
operating system's available fonts; Microsoft fonts are not redistributed.

Home and furniture store: **Pixel Lands - Interiors Demo v1.0**, by **Trislin**.
Source: https://trislin.itch.io/pixel-lands-interiors
The free demo permits commercial and non-commercial game use; raw assets may
not be redistributed or resold. Credit is appreciated, not required. The local
package terms are preserved in `PixelLands-INFO.txt`. Only the free demo is used.
The atlas is locally copied to `assets/home/interiors_demo.png`, excluded from
Git, and included as an imported texture in the local game build. Run
`tools/asset-pipeline/import_home_assets.ps1` after obtaining the free demo to
reproduce the artwork on a fresh checkout. A code-drawn placeholder is used
when the local atlas is absent. No paid assets or AI reference generation are
used for home furniture. Chair and sofa orientations select existing regions;
other furniture retains its single authored view. The top-down prototype reuses
the selected platformer character sprites; new four-direction character art is
not included in this version.

This game uses the Godot Engine under the MIT license. See GODOT-LICENSE.txt
and https://godotengine.org/license/ .
