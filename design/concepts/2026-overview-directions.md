# MoneyWise — three comparable Overview directions

**Status:** the preview compares D1/D2/D3 using the same Overview data. The owner-approved direction is Soft Matte Fintech / composition A «Тихий горизонт» (DEC-008), represented by D1 in this comparison; D2/D3 are review-only alternatives. The comparison is not an owner request to reselect direction, and is not a final native artboard.

## Shared scenario (identical across directions)

- Current manually entered total: **416 500 ₽** (demo value in web preview).
- “Свободно до поступления”: **42 500 ₽** in earlier concept baseline (older synthetic scenario); current forecast branch uses **7 500 ₽** after minimum reserve, named reserves, goal, confirmed obligations and estimated daily spend.
- Minimum protected floor: **180 000 ₽**; named planning envelopes: **35 000 ₽**; goal: **136 000 ₽**.
- Nearest confirmed obligation: rent **32 000 ₽** on 30 Oct.
- Next salary: **92 000 ₽ expected, not confirmed**, never included as currently spendable.
- Same account, event, reserve and transaction content in all concepts. Do not use actual user records in screenshot exports.

The earlier 42 500 ₽ and current 7 500 ₽ belong to different preview baselines. A comparable D1/D2/D3 set must select one exact scenario and render it identically in all three; mixing those baselines would invalidate the comparison.

## D1 — Quiet Precision / Japanese Editorial

**Composition:** restrained dark paper/graphite canvas; large available amount aligned to a strict baseline; next obligation and next confirmed income occupy compact but readable date annotations. One rose marker identifies the nearest dated flow. Calculation expands in rows; no hero card stack.

**Living Card:** object is represented by a single precise balance plane; metal is limited to its edge and a traveling specular line on direct drag.

**Time Machine:** linear date rail with explicit confirmed/expected legend; chosen date controls the same displayed number and calculation.

**First risk:** typography can become hairline/minuscule editorial affectation. **Mitigation:** body labels at normal iOS sizes, one reading order and Dynamic Type.

**Closest existing evidence:** A / Editorial screenshot, but not a faithful D1 render yet: `outputs/okaneyan-concept-a-desktop.png`, `outputs/okaneyan-concept-a-mobile.png`.

## D2 — Obsidian Instrument / Tactile Metal

**Composition:** matte black instrument shell around one graphite/titanium Living Card; the remainder is paper/graphite rows with hard alignment and small rose state markers. No full-screen shiny gradients. A single physically legible light travels across the card only while the user touches/drags it.

**Living Card:** brushed direction is implied with very low-contrast linear microstructure and one specular edge; values remain on a stable matte inset with no reflection over text. The planning lock is a short shutter-like state with visible “Защищено в плане” and Undo.

**Time Machine:** instrument scale ticks and one selected-date cursor; data changes synchronously with the selected date.

**First risk:** metallic decoration may read as a generic crypto device or look like a fake bank card. **Mitigation:** no card number/network marks; object contains only real account and protection information.

**Closest existing evidence:** C / Precision, but it has no material study: `outputs/okaneyan-concept-c-desktop.png`, `outputs/okaneyan-concept-c-mobile.png`.

## D3 — Editorial Utility / Controlled Disruption

**Composition:** a ledger-like vertical sequence, interrupted once by a displaced annotation of the next obligation. Table rows remain strict; the one offset is the entry point into the horizon, not decoration. Stronger asymmetry than D1, tighter information density than D2.

**Living Card:** the card splits actual/free/reserved values into a short indexed specification; one concise summary remains visible.

**Time Machine:** date and cash events read as a vertical issue/ledger, then a small scenario comparison line shows “без покупки / с покупкой”.

**First risk:** the screen may become a faux bank statement. **Mitigation:** preserve a clear available-to-spend answer and natural Russian labels; no institution codes or fake statements.

**Closest existing evidence:** B / Zine, but not a faithful D3 render yet: `outputs/okaneyan-concept-b-desktop.png`, `outputs/okaneyan-concept-b-mobile.png`.

## Comparative critique (same screen, pre-prototype)

| Criterion | D1 Quiet Precision | D2 Obsidian Instrument | D3 Editorial Utility |
|---|---|---|---|
| Fast “what can I spend?” answer | strongest | strong if card has one stable focal number | medium; risk of rows leading |
| Signature/materiality | typography + date mark | best material potential, high fake-bank risk | type/offset rhythm, low material |
| Transaction density | low/medium | medium | highest |
| Mobile behavior | vertical order; low horizontal risk | card must shrink without tiny insets | dense rows need careful line wrapping |
| Motion role | amount anchor + short line drawing | direct-touch specular response + shutter state | rows settle and selected event shifts once |
| Anti-AI risk | medium: generic “calm editorial” is a known generated default | medium/high: metallic fintech card is also a template trope | medium: “zine” can become generic newspaper UI |
| Current evidence | A screenshot only | C screenshot, material proof missing | B screenshot only |

## Approved direction and prototype scope

Keep the owner-approved dark Editorial/Okaneyan identity and composition A **D1 Quiet Precision / «Тихий горизонт»** as the product's everyday base (DEC-008). D2/D3 remain comparison-only. The narrow D2 matte-edge treatment is an optional web-preview study for the Living Card, supported by R-13/R-14; do not extend it to tables, Gravity, or the full canvas. Direction approval is complete; implementation fidelity and independent critique are still under review.

### Decision ledger

| Decision | Evidence | Role | Why |
|---|---|---|---|
| Keep the available amount first and expose its arithmetic | Morrow case, MoneyWise current user intent, FinanceEngine data | Overview hero / expanded card | Removes calculation burden while preserving explanation |
| Keep confirmed vs expected income semantically explicit | MoneyWise core + Copilot/Monarch product docs | Timeline states | Prevents projected money being mistaken as available |
| Use metal only on card body | supplied MoneyWise visual brief + titanium/product cases to inspect further | Living Card material | Keeps material signature local and avoids generic all-screen gloss |
| Do not use decorative orbit as the system's identity | user anti-goal; Gravity's categories are overlapping planning dimensions | Gravity | Avoids implying separate assets or physical movement |

## First interactive prototype checkpoint — 2026-10-29

- The picker now exposes D1 Quiet Precision, D2 Obsidian Instrument and D3 Editorial Utility on the same Overview data. The primary amount remained **7 500 ₽** and the same rent/income dates were present while switching.
- D1 currently maps to the previous Editorial CSS foundation (`concept-a`); D3 maps to the previous Zine foundation (`concept-b`). Their names now describe target directions, but these implementations are still approximations and need source-backed redesign rather than relabeling as finished work.
- D2 maps to the previous Precision structure (`concept-c`) and adds a restrained dark brushed treatment to the Living Card only. It was inspected in dark and light themes and with the breakdown expanded. The other dashboard sections remain on their current page theme.
- In the live in-app preview, the selected direction updated and `document.documentElement.scrollWidth` remained within the available 600 px viewport. This does **not** verify 390/768/1440. The screenshots were displayed in the browser inspection but are not saved as repository artifacts.
- The transition produced a brief overlapping capture while in progress; after 800 ms the rendered state was clean. This is a capture timing note, not yet a measured or recorded motion pass.

## Required next comparison capture

Render D1/D2/D3 on the same 1440 desktop, 768 tablet and 390 iPhone viewport with identical demo scenario. Capture first-load, expanded card, hidden amount, no balance, negative forecast and both themes. Record at least one actual user-triggered motion for each. Existing A/B/C screenshots are archived baseline only; they must not be silently re-labeled. Current prototype previews are a first comparison checkpoint only.
