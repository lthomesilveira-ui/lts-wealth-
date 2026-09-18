# V173 — V172 user feedback register — 18/09/2026

Status: OPEN FOR IMPLEMENTATION ON HOMOLOGATION ONLY
Baseline: V172 fixed homologation
Public root: protected; no production promotion authorized

## Continuity rule
This register exists so the feedback below never depends on chat memory. Preserve it in full until each item has specific implementation and validation evidence. The user may continue making real entries in V172 while this package is developed. Treat the database as live, refresh current reads before validations, do not overwrite user changes, do not depend on frozen snapshots, and do not retain test mutations.

## User feedback captured from V172 review

### F01 — Smart-entry category interpretation
The user entered natural language equivalent to:
`registrar entrada conta conta corrente itaú 420,00 classificado como Família em 17/09/2026`.

Observed behavior:
- date/value/nature/account were interpreted;
- `Família` was not reliably resolved into the Category field.

Required:
- improve category interpretation against the canonical category vocabulary;
- accents/case/spacing must not cause a new or wrong category;
- interpretation may suggest an existing category only; never fabricate a category from ambiguous text;
- retain explicit user review before confirmation.

### F02 — Category control must be canonical/selectable
Observed: Category is currently presented as a free-text-like field in the smart-entry review.

Required:
- expose a dropdown/select/autocomplete sourced from the canonical existing category list;
- user must be able to choose the exact canonical category before confirming;
- prevent typo/accent variants from silently creating parallel category names;
- preserve the reviewed natural-language input workflow.

### F03 — “Ver composição” only when it adds information
Observed: Despesas > Categorias keeps expandable composition even when the detail merely repeats the parent.

Required:
- show/enable `Ver composição` only when there are at least two meaningful child components or when the child level adds a materially distinct dimension;
- suppress one-child/no-information repetition;
- examples explicitly reported:
  - `Empréstimos` makes sense because composition includes distinct Itaú and Coopharma components;
  - `Benjamin — Educação` -> only `Educação` is redundant and should not expand in this form;
  - energy -> only Enel is redundant and should not expand in this form;
- if a professional hierarchy is available, prefer a useful split (example: Educação -> Benjamin / Lucas) rather than parent -> same concept.

### F04 — Financing imobiliário identity / duplicate meaning
Observed: `Financiamento imobiliário` / “casa” presentation is unclear. The user states there is only one real-estate financing and does not understand why a separate/duplicate-looking identity exists.

Required:
- trace the source rows/read-model grouping behind the displayed real-estate financing labels before changing anything;
- determine whether this is duplicate naming, parent/child repetition, multiple source labels for the same commitment, or genuinely distinct evidence;
- do not merge financial facts until source identity is proven;
- final UI should not imply multiple real-estate financings if the evidence proves one.

### F05 — Vehicle financing cannot be “Não identificado”
Observed: category rank item `Financiamento de veículo` expands to `Não identificado`.

Required:
- trace the underlying financing/source identity and existing vehicle evidence;
- identify the commitment correctly from available evidence;
- do not leave `Não identificado` when the source can be deterministically associated;
- do not invent lender/vehicle if evidence is insufficient; escalate only the unresolved factual decision.

## User concurrency / live-use decision
The user asked whether V172 can keep being used while V173 is developed.

Working contract:
- YES: V172 remains the stable homologation baseline and can continue receiving real user entries;
- V173 development must not require a data freeze for this scope;
- implementation/tests must avoid destructive database changes and test writes that survive;
- always re-read current data before parity assertions because the user may add/edit entries during development;
- if a future operation genuinely requires a temporary write freeze, request it explicitly before that operation rather than assuming one.

## Acceptance targets
- Natural-language `Família` example resolves to the canonical existing category or clearly asks the user to select it.
- Category review offers canonical selection and cannot silently create typo/accent duplicates.
- Category composition toggles appear only where the drill-down adds meaningful information.
- Real-estate financing presentation is source-traced and non-duplicative.
- Vehicle financing is source-traced and not shown as `Não identificado` when deterministic evidence exists.
- V172 production/public-root protection and all V150/V151+ Flow contracts remain unchanged.
