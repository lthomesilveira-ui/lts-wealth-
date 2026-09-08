# Canonical app v1.13 Classification-first Updates + Guided Document Intake checkpoint — 08/09/2026

## Purpose
- Recover the validated V147 `Atualizações` hierarchy instead of treating later reduced layouts as the product floor: classification is the primary action and documents/management remain secondary, collapsed actions.
- Restore one visible, guided document-intake path with explicit association before upload, while preserving the rule that an uploaded file is evidence and never an automatic financial posting.
- Preserve canonical v1.12 reviewed input, v1.11 layered liquidity, v1.10 decision truth, v1.9 V150/V151+ Flow parity and every later security/session improvement.

## Exact release
- Repository: `lthomesilveira-ui/lts-wealth-`.
- Product parent: v1.12 documentation closure `dad0db7a838840e73e340cbf9f5748188cf0577c`.
- Exact remote product commit: `6d2b546b5e32d9ac09013cbd682e261e3f41ccac`.
- Exact product tree: `ae4710f80a7ed60c6e0b00c801b9814143edc84a`.
- Fixed-manifest exposure commit: `6a25aa99ab9548ef001870d9303d65700a0da8ec`.
- Exposure tree: `ebc49406160e31f2d988825392fe642fb35e85df`.
- Local product commit `833b3048e9dc7d4d866f49d403fe8e148b164538` has the exact same product tree; its different SHA is only the local/remote parent-lineage difference.
- Updates/document contract: `classification-first-guided-document-intake-v1`.
- Existing document register writer: `lts_browser_register_document_v2`.
- Private Storage bucket: `lts-documents`.
- Build label: `LTS v1.13`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` remains blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; `promotion_status:not_promoted` remains binding.

## Historical recovery and product decisions
- V150 is the protected functional floor for Fluxo Diário; V150–V152 retained the rich interactions, V153 reduced the surface, and V154–V160 did not restore all interactions. V1.13 does not alter the recovered v1.9 Flow contract.
- V147 established the approved Updates priority: classification stays in the foreground; `Outras ações que precisam de você` contains documents and secondary management actions. Putting documents above classification was rejected.
- V147 also established explicit association: bank statement → institution/account + competence; card statement → card + competence; financing → commitment + exact as-of; other financial document → optional explanatory note/manual review.
- No final approved standalone Reports visual was recovered. This package does not invent one and preserves the existing executive JSON/recurrence CSV controls.

## Product behavior protected
- `Atualizações` renders the classification queue first.
- Reviewed text input, Aplicar/Resgatar and Central de Gestão have explicit stable hosts and do not compete for the route DOM.
- `Outras ações que precisam de você` is collapsed by default and owns the priority queue plus the document section.
- Same-route navigation to a target anchor opens the enclosing collapsed section and scrolls to it without rerendering the whole route. This fixes a discovered remount bug that could erase asynchronously mounted modules when `Documentos` was selected from the current route.
- Document types are bank statement, card statement, financing document and other financial document.
- Required association changes with type and is reviewed before upload. File name is never used as account/card/competence/date/value evidence.
- Client guard accepts the documented formats and blocks files larger than 50 MB before transfer.
- A real confirmed upload writes to the private `lts-documents` bucket, registers metadata through `lts_browser_register_document_v2`, and removes the uploaded object if registration fails.
- Upload/registration creates documentary evidence only. Interpretation, human review and any later financial write remain separate; no auto-post path was added.
- Fixture mode disables file selection/upload. The permanent gate requires `writer_called:false` and `write_accepted:false`.

## Deterministic evidence
- `git diff --check`: PASS.
- Inline HTML JavaScript parse and `node --check` for changed modules/gate: PASS.
- Local permanent browser gate: PASS in Chromium desktop 1312×1199 and mobile 390×844.
- Local visual review: classification first, collapsed secondary actions, guided document form, opened anchor behavior and no horizontal mobile overflow.
- Button contract audit: 197/197 controls wired.
- Candidate smoke script: PASS.
- Protected `index.html` hash remained exact.
- Recovery product gate/smoke `34242926042` / `34242925889`: SUCCESS.
- Canonical product gate/smoke `34243185722` / `34243185837`: SUCCESS.
- Main product smoke/Pages `34243383377` / `34243381614`: SUCCESS.
- Post-exposure active/canonical/main smokes `34243737853` / `34243795334` / `34244113857`: SUCCESS.
- Post-exposure Pages `34244111908`: SUCCESS.
- Recovery artifact `10062796446`, digest `sha256:bb51419f7772a7504b4556bb89d017b8297165d3f01d92f0cb8ff26bd92d1667`.
- Canonical artifact `10062906709`, digest `sha256:3f19198c6ab8256323cdc7b9b56b19401cd39e0c823322d5c1e5bf5524f99480`.
- Product Pages artifact `10062926189`, digest `sha256:7d5a8ff98273a9c97cb470072e2d505aa47632fac5a5225b5e79c4a928a40c26`.
- Exposure Pages artifact `10063227934`, digest `sha256:ab16d51a56c57d5cdb80b37fa72ee8b25b7e4b8caf95a6d7d36f7890bf07b2a3`.

## Live fixed-URL evidence
- The fixed URL resolved to `canonical-app.html?homologacao=6d2b546b5e32d9ac09013cbd682e261e3f41ccac&…#Dashboard`.
- GitHub Pages loaded `canonical-liquidity.js?v=20260908-updates13` and `canonical-liquidity-core.js?v=20260908-updates13`.
- A clean signed-out browser rendered the real LTS Wealth login, not fixture financial content.
- Zero iframes and zero fixture KPI values were present.
- No application console/page error was observed; extension-only browser metadata logs are outside the product.

## Validation boundary
- Local and CI fixture gates prove hierarchy, association controls, no-write fixture behavior, navigation/remount safety, responsive layout and preservation of the preceding product contracts.
- They do not prove a real authenticated file upload, Storage policy, register/readback lifecycle, interpretation result, classification write, reviewed-input write, liquidity write, backup/restore apply or real-data Dashboard.
- Physical-iPhone authenticated validation remains open and cannot be inferred from Chromium/WebKit CI.
- Public-root promotion is not authorized and was not performed.

## Next execution sequence
1. Preserve product `6d2b546…`, exposure `6a25aa9…`, the V147 classification-first hierarchy and all v1.12→v1.9 protected contracts.
2. Continue evidence-backed product refinement and the two-project history audit; do not invent a Reports model or documentary/financial facts.
3. Execute authenticated search/classification/input/liquidity/document/backup-restore lifecycles when a real authenticated browser identity is available, recording write and readback evidence separately.
4. Keep documentary gaps, Open Finance provider/consent/spend and public-root promotion explicit; only the latter decisions require the user before action.
