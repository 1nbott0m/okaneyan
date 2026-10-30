# MoneyWise decisions and open questions

This file records user decisions recovered from the three supplied chat handoffs. The original chat archives were not supplied in full; quote-level provenance is therefore limited to the handoff package.

## Accepted decisions

| Decision | Current rule | Provenance / status |
|---|---|---|
| Native product | iPhone app in Swift/SwiftUI; browser preview is not production | Repeated user decision, consolidated from UI and core handoffs |
| Local data | No account/server required; financial records remain local | User decision, reflected in `PRODUCT_SPEC.md` |
| Bank access | Automatic sync desired, but only official bank-approved direct iOS access; no backend, intermediary, aggregator, scraping, or credential collection | Later and more specific user constraint; direct route remains unconfirmed |
| CSV | Supported fallback/import path; manual daily download is not an acceptable final sync experience | User clarification; CSV does not close auto-sync requirement |
| Financial advice | Explain concrete amounts/dates; no shame; future income is forecast, not current cash | User decisions and product spec |
| Purchase model | Deterministic MoneyCore; scenario is not a transaction until explicit save/confirmation | Product contract and current architecture |
| External AI | Deferred; local AI may be revisited later | Explicit user change |
| Brand | `okaneyan.` lowercase with period; dark Okaneyan/Editorial base | User-provided identity and design decisions |
| Orbit motion | Integrate the supplied Orbit O component; dismiss only when the mounted app root reports ready; honor Reduce Motion | Current user explicitly requested the approved Orbit O materials be integrated into the unified iOS app |
| Open source | User expressed intent, but no license selected | Open decision |

## Open questions that must not be silently decided

- Whether a requested retail bank will approve direct on-device iOS API access and what native auth/token constraints apply.
- Final purchase-verdict wording/scoring thresholds where “strict” guidance and nonjudgmental tone meet.
- Whether every icon colorway is required for app-icon release; launch animation geometry is now integrated from the requested Orbit O master.
- Whether the static “Линия до события” concept is selected; viewing the concept is not approval.
- A concrete open-source license.

## Rejected or constrained

- No backend or aggregator for bank sync under current user decision.
- No synthetic finance data represented as real account data.
- No claims of bank/card/payment locking.
- No return to heavy cinematic Orbit effects without a new user decision.
- No external AI processing in the current MVP.

For implementation details and historical uncertainty see the [consolidated three-stream handoff](HANDOFFS/three-stream-handoff.md), based on the source packet at `/Users/yan/Documents/Codex/2026-10-30/referenced-chatgpt-conversation-this-is-an-2/outputs/MoneyWise_полный_пакет_передачи.md`.
