# V165 user-accepted baseline — immutable recovery checkpoint

Date: 16/09/2026  
Status: preserved before V166 refinement work

## Exact recovery coordinates

- Published product commit: `6bcdfb1f78baf944e6f215da045b75ef3244d4de`.
- Candidate: `wip35-v165-candidate.html`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- The current `main` baseline used by V166 is `7487185b0f83cf7d7430d2e3ccc307242cd625c1`; it contains the later Flow correction that preserves user-moved events after documentary anchors.
- The public `index.html` remains protected and is not promoted by this work.

## User acceptance boundary

The user reported V165 as a large visual evolution and confirmed the 14/09/2026 Flow closing balance after the subsequent Flow correction. V166 is therefore an additive refinement package. V165 files, release receipt, branch and candidate must remain recoverable without depending on chat memory.

## V166 non-regression contract

- Preserve the V165 dark rail/light canvas visual system and five-route navigation.
- Preserve the corrected Flow balance chain and append-only mutation model.
- Do not overwrite the V165 candidate, JavaScript, CSS, workflow or receipt.
- Deliver V166 through new versioned files and a separate candidate.
- Any financial writer added by V166 must be user-scoped, audited and reversible.

