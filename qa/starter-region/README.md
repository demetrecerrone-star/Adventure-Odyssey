# Full starter-region terrain harness

Isolated QA project; production bedroom entry and saves are unchanged. No Android export, building population, encounters or working exit transitions.

## Runtime
4608×3072 native painted terrain, 54 chunks with 512px cores and two copied-neighbor gutters. All coordinates are world coordinates. The original corridor sits at [1344,768]; no extra origin offset is applied. Static 96px actor and current analog joystick exercise155px/s movement. This harness does not certify animated gait.

Camera clamps at every edge for zoom1/1.5/2; inward-rounded bounds avoid a fractional float overshoot. Visible chunks plus128px margin are loaded directly and freed outside the window; no hidden permanent texture cache. Local full-region sweep peaks at12 chunks /12.188MiB decoded RGBA estimate,398 loads392 evictions. Process/GPU/mobile memory and synchronous-load hitching are unmeasured.

## Physics scope
All11 reserved lots are provisional solid polygons in this isolated test, not placed buildings. Existing three corridor terrain colliders are retained. Additional broad river-bank and forest/northeast shelf polygons were traced from the terrain overview for QA; they are deliberately provisional and do not constitute a complete fine terrain collision pass. Small rocks/ledges remain scenery-placement work. World boundaries are solid and future exits remain disabled.

Five72px-wide engine sweeps and actual CharacterBody2D traversals pass at155px/s, plus representative river/cliff/home/boundary rejection probes. Future-exit route endpoints are moved from24px to40px inward in the QA layout only, so the36px radius clearance probe fits inside solid world boundaries. Original navigation.json records unmodified planning endpoints.

Local Godot4.6.3:33 checks pass. Hash/opaque coverage/copied gutters and five route-vs-lot/water-mask checks pass. Water-mask overlap is only an additional image-space check; it is not the collider source or proof that every bank is traced.

## Native gate
CI renders10 views: home, guild, forest/meadow/foothill edges, south river, fractional chunk crossing at1/1.5/2×, and southeast corner. Every view compares streamed chunks against one reconstructed full texture, threshold2/255. Three motion stills accompany this. Native results remain pending until downloaded and visually inspected. Software Mesa/X11 is not Android hardware performance.

Ground art is frozen from the supplied starter-ground-v2 package; pixel hashes remain exact. Native1:1 detail is retained, while2× magnification naturally softens source pixels. Buildings, tall vegetation, interactions and full populated-map QA remain open.
