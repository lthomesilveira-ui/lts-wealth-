# Canonical app v1.14 Document Interpretation Review checkpoint — 08/09/2026

## Purpose
- Recover the read-only document interpretation review evidenced in V149 and lost from the later canonical surface.
- Let the user compare the association explicitly supplied during intake with the evidence extracted from the file, without turning review into approval, classification or a financial write.
- Preserve canonical v1.13 classification-first Updates and guided intake, v1.12 reviewed input, v1.11 layered liquidity, v1.10 decision truth, v1.9 V150/V151+ Flow parity and every later security/session improvement.

## Exact release
- Repository: `lthomesilveira-ui/lts-wealth-`.
- Product parent: v1.13 documentation closure `4a38007…`.
- Exact remote product commit: `0d50699af5aa5b950ff889a1fc6becfee209ce06`.
- Exact product tree: `f086c6878f4737a10c6865768241e9d2c4adc326`.
- Fixed-manifest exposure commit: `ac5d4674920615c6c5e5947d4ab721f538679a0c`.
- Exposure tree: `e4d9796e6646a2265ca62c5de4b7058ac6b487cb`.
- Local product commit `5851bf9…` has the exact same product tree; its different SHA is only the local/remote parent-lineage difference.
- Document-review contract: `v149-evidence-review-readonly-canonical-v1`.
- Browser RPC: `lts_browser_document_review_queue_v1`.
- Internal read model: `lts_document_review_queue_v1`.
- Applied migration: `canonical_document_review_read_model_2026_09_08`.
- Build label: `LTS v1.14`.
- Asset cache tag: `20260908-doc-review14`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` remains blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; `promotion_status:not_promoted` remains binding.

## Historical recovery and product decisions
- V149 contained a read-only document surface that contrasted the user-supplied association with extracted evidence. That visibility was absent from the canonical line even after v1.13 restored guided intake.
- V147 remains binding for priority and intake: classification is foreground; documents and secondary work stay under collapsed `Outras ações que precisam de você`; association is explicit and type-specific before upload.
- V150 is the protected functional floor for Fluxo Diário. V150–V152 retained the rich interactions, V153 reduced the surface, and V154–V160 did not restore all of them. V1.14 preserves the recovered v1.9 Flow contract unchanged.
- No final approved standalone Reports visual was recovered. This release does not invent one.

## Product behavior protected
- `Atualizações` remains classification-first, and the document area remains secondary/collapsed by default.
- Every review card separates `Vínculo informado por você` from `Leitura extraída do arquivo`.
- Evidence rows are bounded and escaped before rendering; missing association receives an explicit warning instead of an inferred link.
- The review surface is labelled `Somente leitura` and contains no button, input or implicit mutation path.
- Reviewing extracted evidence cannot approve, reconcile, classify, overwrite association or post a financial fact.
- Guided upload remains private and non-financial; filename remains non-authoritative.
- Fixture mode proves `write_allowed:false` and `financial_writer_called:false`.

## Backend and security boundary
- `lts_document_review_queue_v1` is a stable, owner-scoped internal reader. It filters to file/photo/PDF evidence requiring review, excluding rejected/discarded records.
- The result limit is clamped to 1–6; extracted entry arrays are capped at 25; bounded JSON roots are limited to 32 KB each.
- `lts_browser_document_review_queue_v1` is the only authenticated browser entry point and calls `lts_browser_assert_user_v1` before delegating.
- The browser wrapper is `SECURITY DEFINER`, stable, executable by `authenticated` and `service_role`, and not executable by `anon`.
- The internal reader is not `SECURITY DEFINER` and is executable only by `service_role`.
- A random zero-UUID probe returned the exact contract/version, zero items and both write flags false. An unauthenticated wrapper probe failed with `42501 unauthorized`.
- Security Advisor reports the expected generic authenticated-`SECURITY DEFINER` warning for this guarded browser wrapper; no new document-review performance finding exists.

## Deterministic evidence
- `git diff --check`: PASS.
- Inline HTML JavaScript parse plus `node --check` for changed JavaScript and gate files: PASS.
- Local permanent browser gate: PASS in Chromium desktop 1312×1199 and mobile 390×844.
- The gate covers two document fixtures, at least twelve evidence rows, exact contract, association/missing-link states, zero interactive controls and zero writer calls.
- Local visual review: classification hierarchy retained, review cards readable on desktop/mobile and no horizontal overflow.
- Button contract audit: 197/197 controls wired; zero unresolved/anonymous controls.
- Protected `index.html` hash remained exact.
- Product recovery gate/smoke `34250450654` / `34250450670`: SUCCESS.
- Canonical product gate/smoke `34250649137` / `34250649010`: SUCCESS.
- Main product smoke/Pages `34250977997` / `34250976391`: SUCCESS.
- Post-exposure active/canonical/main smokes `34251224292` / `34251281745` / `34251333462`: SUCCESS.
- Post-exposure Pages `34251332488`: SUCCESS.
- Recovery artifact `10065805910`, digest `sha256:50a3687a1ff0d86dc74c0c8a7d2be6066b0b47a5634f1f392692237de30322c7`.
- Canonical artifact `10065921441`, digest `sha256:7a292b5f5ce280ebac2f57ae53520d45bf37fcaa2d145a6351100e0f2f2a4a18`.
- Product Pages artifact `10065959962`, digest `sha256:d2f503f173dfb1ace4eaeffd4fddcc244e0e6caf9fc480129f0fc0b61e6820bb`.
- Exposure Pages artifact `10066100348`, digest `sha256:8d3f15e7be00a045f48066859f833bf2b79df7a23eac652742090056ae6fb36e`.

## Live fixed-URL evidence
- The fixed URL resolved to `canonical-app.html?homologacao=0d50699af5aa5b950ff889a1fc6becfee209ce06&…#Dashboard`.
- GitHub Pages loaded `canonical-liquidity.js?v=20260908-doc-review14`, `canonical-liquidity-core.js?v=20260908-doc-review14` and the canonical Dashboard stylesheet with the same tag.
- A clean signed-out browser rendered the real LTS Wealth login, not fixture financial content.
- Zero iframes, zero fixture badge and no raw JWT were present.
- No application console/page error was observed; extension-only browser metadata logs are outside the product.

## Validation boundary
- Local and CI fixture gates prove the read-only review contract, association-versus-evidence separation, bounded rendering, no-write behavior, responsive layout and preservation of preceding contracts.
- They do not prove upload/register/interpretation/readback with a real authenticated user document.
- No authenticated classification, reviewed-input, liquidity, Flow mutation, backup/restore apply or real-data Dashboard write/readback is claimed.
- Physical-iPhone authenticated validation remains open and cannot be inferred from Chromium/WebKit CI.
- Public-root promotion is not authorized and was not performed.

## Next execution sequence
1. Preserve product `0d50699…`, exposure `ac5d467…`, the V149 review contract, V147 classification/intake hierarchy and every v1.13→v1.9 protected contract.
2. Execute the real authenticated document lifecycle when an authenticated browser identity is available: upload → register → lifecycle → interpretation → read-only review, proving that no financial writer runs.
3. Continue the evidence-backed two-project recovery and product refinement; do not invent a Reports model or documentary/financial facts.
4. Keep authenticated financial writers/search, backup/restore, physical iPhone, Open Finance provider/consent/spend and public-root promotion explicit; only decisions/access that cannot be derived from evidence may block autonomous work.
