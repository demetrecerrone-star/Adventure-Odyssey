# Reviewed painted-walk migration batches

The catalog at assets/painted-walks/catalog.json selects explicitly reviewed base/class manifests. Each direction validates paired six-cell body/armor, isolated palette mask, hair registration and matching equipped-weapon layers before replacing the existing animation. Missing entries retain their own prior artwork; identities never borrow another base or class.

Initial batch: female Warrior four directions, six drawings at9fps and155px/s. Hair uses original female directional idle cells with fitted affine transforms: down0.88,left0.90,right0.86,up0.82. Source and target crowns are registered per frame. The actual female Warrior sword is re-registered with source grip-hole compensation and body silhouette occlusion. The first local batch passes25,184 checks; native palette/hair/sword captures and an actual bedroom cycle must pass before visual completion is reported.

The previously verified male Warrior four-direction set remains unchanged. The other ten base/class outfits remain on their prior eight-frame artwork until their batches are ready. The current batch does not migrate combat, idle, or other animation categories. No APK until the map milestone is complete.

Known art limits: side poses have high knees and uneven phase spacing; source sole-edge pixels reach the crop boundary in two right poses. female skull/body proportions differ slightly from original idle; footplants are unverified and arm variation modest. The fixed9fps at155px/s can still show foot sliding. Source extraction from white-matted drawings estimates edge alpha.

Next batch: female Paladin four directions, six drawings at9fps/155px/s. Uses actual paladin_01_weapon, with left blade behind the body and right blade in front with hand/wrist occlusion. White tabard, steel, gold and leather remain outside skin tint. All15 original female hairstyle registration contacts were reviewed before import. Higher-knee side poses and mirrored right lighting remain source-art limits; native capture is required. Local full suite:25,276 checks pass. Male Paladin is not enabled yet; its final extraction review is still pending.

Male Paladin batch: all four directions, using final down-v2 skin masks and registered original Paladin sword (including right/up source-hand-hole correction). All24 body/armor recompositions and360 hairstyle registrations were source-reviewed. Native review remains required; elevated passing knees and unverified footplants remain disclosed. Full local regression:25,368 checks pass.
