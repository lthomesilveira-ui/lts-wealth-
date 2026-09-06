# LTS Wealth — Canonical App v1 liquidity UI gate checkpoint — 06/09/2026

## Purpose
Immutable evidence for the first canonical frontend surface that exposes the already-proven bank↔cash-investment liquidity writer without changing the economic contract.

## Source state
- Canonical branch gated source commit: `9fbe90a28f96436546a1f3d1b923c0f7a57e7c1a`.
- Post-gate cleanup head: `865e3a3059348e13fc02cb79d325acaf279e1423` (only removes the one-shot integration workflow).
- `canonical-app.html` blob after wiring: `4d847449208dd80bf31e74238c79a0dd411cda38`.
- `canonical-liquidity.js` blob: `eee099e254569d955a64216edce1322613882644`.
- Protected public `index.html` remains unchanged; no public-root promotion is authorized.

## User surface now implemented
`Atualizações` now contains a compact `Aplicar / resgatar` flow that requires explicit user selection of:
- application vs redemption;
- bank account;
- documented cash-investment asset;
- positive amount;
- today/future event date.

The frontend then:
- requests the backend preview;
- shows equal-and-opposite bank and asset legs;
- shows effective asset before→after when returned;
- displays economic effect `R$ 0,00` and explicitly states that the movement is not income/expense;
- requires an explicit confirmation checkbox before the writer is enabled in real mode;
- submits the exact preview with an idempotency key;
- re-reads product + cockpit after write and validates same-day bank/D0 deltas before presenting success;
- never enables the writer in deterministic fixture mode.

The existing backend contract remains unchanged: today/future browser movements only, explicit approval, user-owned active bank account, documented `cash_investment` asset, equal-and-opposite legs, no second economic effect and idempotency protection.

## Deterministic frontend gate
Canonical gate run `34053651814`: **SUCCESS**.

Validated in:
- Chromium desktop 1312×1199;
- WebKit mobile 390×844.

The gate preserves the prior six-route regression coverage and additionally validates:
- `canonical-liquidity.js` syntax and required browser RPC contract;
- exactly one liquidity card in Atualizações;
- explicit Application preview using fixture account/asset;
- parsing of `5 mil`;
- visible neutral effect `R$ 0,00`;
- no fixture writer / no accidental financial mutation;
- no iframe, horizontal overflow or page error;
- truthful unauthenticated login fallback.

Artifact `9995321790`, digest `sha256:443efb8995d2be17450a2406acfc59357954b000a2e9fea543261d47d08a8d66` contains canonical HTML/JS plus desktop, mobile and Atualizações screenshots.

This is deterministic fixture + unauthenticated browser evidence. It is **not** authenticated physical-iPhone financial/data E2E and must never be represented as such.

## Financial invariants unchanged
No real user liquidity movement was posted by this frontend gate. Current audited canonical invariants remain:
- bank cash R$15.794,43;
- D0 R$42.929,50;
- vested D+3 R$12.909,65;
- through D+3 R$71.633,58;
- documentary FGTS R$22.432,31 at 21/08/2026, restricted / approximately D+30, with no future-accrual estimate.

## Visual/product audit after gate
The new Atualizações surface is materially more functional and compact than the prior canonical baseline. The Dashboard remains the next absolute priority: deterministic screenshot evidence still differs materially from the approved official 1312×1199 reference in navigation breadth, top KPI framing, historical-wealth chart availability/shape, monthly controls, density and several secondary card details. Financial values must continue to come only from real evidence; the approved image defines presentation/hierarchy, not values.

## Open dependencies preserved
- authenticated physical-iPhone canonical financial/data E2E;
- real authenticated liquidity save→refresh→visible (user action required to post a real movement; deterministic writer remains disabled);
- real authenticated classification lifecycle and PDF/image interpretation→review;
- expense density / evidence-only `A classificar` reduction;
- Mastercard/Visa documentary gaps;
- RSU sale documentary detail where absent;
- CIPÓ unresolved deltas/source gaps;
- Volvo exact trim/km;
- Open Finance provider/commercial/consent decision boundary;
- public root promotion only with explicit user authorization.
