# LTS Wealth — Canonical v1.23 Daily-Use Flow Closure Checkpoint

Date: 2026-09-09

## Exact release

- Product commit: `7f6bac39ec0705e21a498b416762276ea3b8dbea`.
- Fixed-manifest exposure: `d804eb0b5e972d2e86f8abc57d375e4de3e82219`.
- Branches `canonical-v157plus-product-recovery`, `canonical-app-v1` and `main` are aligned by normal no-force fast-forward.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` was not changed; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Closed product contracts

- `mobile-layer-disclosure-open-closed-invoice-actions-v1` preserves all 14 consolidated desktop columns and makes the nine future-liquidity layers available per day on mobile without forcing the table into a squeezed desktop layout.
- Each mobile day starts compact behind `Ver liquidez do dia`; expansion exposes exactly nine labelled values and can be collapsed again with explicit `aria-expanded` state.
- Open invoices show their current projected cash value and defer purchase composition until closing. Closed invoices preserve reconciled totals, credits, cash×detail delta, categories and full documented purchases. The payment-versus-consumption no-double-counting rule remains explicit.
- Eligible projections support edit, postpone, duplicate, split/substitute and cancel. Inline validation, dialog semantics, tabs, Escape, focus restoration and mobile sticky actions are covered.
- Fixture receipts are append-only and prove the ordered intents `edit → postpone → duplicate → split → cancel` while keeping `writer_called:false`. Existing backend action compatibility is preserved; no financial fact, classification or database contract changed.
- V1.22 Dashboard/Reports and every protected V1.19→V1.9 truth, security, route and evidence contract remain regression-gated.

## Automated evidence

- Product recovery gate `34413082102`: SUCCESS in Chromium desktop 1312×1199 and WebKit mobile 390×844.
- Active candidate smoke `34413082087`: SUCCESS.
- Canonical gate `34413258158` and candidate smoke `34413258173`: SUCCESS.
- Main candidate smoke `34413472119` and Pages `34413471764`: SUCCESS.
- Post-exposure active/canonical/main smokes `34413672709` / `34413684107` / `34413697593`: SUCCESS.
- Post-exposure Pages `34413696615`: SUCCESS.
- Recovery artifact `10128027518`, digest `sha256:243a90c9b03c815af02504e205314635e42aa73d5c29fd83864124e4a39bb863`.
- Canonical artifact `10128113898`, digest `sha256:6ad155400085acabedef69b5f1fc04a16dbc5b1c66eafb542f6cca1377ba6569`.
- Exposure Pages artifact `10128217480`, digest `sha256:12372211c75b4a5ed425f04fc177a8b2305df78957cb2898629642ca6f86d366`.
- A fresh unsigned live fetch resolved the manifest to exact product `7f6bac39…`, build v1.23, `flow23` / `ux23` assets and `promotion_status: not_promoted`.

## Feedback/accountability boundary

- The recovered two-month ledger remains the authoritative set of product, Flow, classification, documentary, financial and operating feedback. V1.23 closes the executable daily-use Flow gaps identified after v1.22; it does not erase unresolved evidence dependencies.
- Bradesco/Cofrinho differences, incomplete card documents, RSU liquidation detail, CIPÓ/Volvo facts and Open Finance provider/consent decisions remain open until documentary or user-owned evidence exists.
- Authenticated real financial mutation/readback, document upload lifecycle and backup/restore lifecycle still require a user-owned authenticated browser session.
- Physical-iPhone material E2E still requires the physical device and is not claimed by deterministic WebKit.
- Public-root promotion remains separate; fixed homologation is updated while `index.html` stays protected.
