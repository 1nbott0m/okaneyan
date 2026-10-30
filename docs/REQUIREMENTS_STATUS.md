# MoneyWise user requirement status

Status describes evidence in the current repository plus the supplied historical handoffs. `IMPLEMENTED_UNVERIFIED` means source exists but the current user flow is not proven end to end. Historical simulator evidence is not a fresh pass of the present dirty checkout.

| ID | User result | Priority | State | Evidence / remaining acceptance |
|---|---|---:|---|---|
| P0-01 | See real included account balance and its freshness | P0 | `IMPLEMENTED_UNVERIFIED` | Account rows now show the checked date/time and visually mark stale/future timestamps. A focused iPhone 18 Pro Simulator account/persistence UI flow passed 1/1 and captured `design/research/evidence/2026-10-30/ios-account-balance-freshness-iphone18pro.png`. Stale/future account-row rendering and the final scroll inset still need one clean simulator confirmation. |
| P0-02 | Add dated obligation and see its impact on available money/forecast | P0 | `DONE_VERIFIED` | On 2026-10-30, targeted iPhone 17e Simulator UI flow created a dated 500₽ obligation and used the same local store for purchase checks. |
| P0-03 | See future income separately from current cash | P0 | `DONE_VERIFIED` | Targeted iPhone 17e Simulator flow verified an explicitly confirmed 5,000₽ future income and the UI note that it is not added to cash before credit; confirmation survived relaunch. |
| P0-04 | Check a planned purchase with amount/date and get concrete verdict | P0 | `DONE_VERIFIED` | Targeted iPhone 17e Simulator flow produced both safe 1,000₽ and unsafe 9,000₽ verdicts using a 10,000₽ account fixture, dated obligation and recent history. Fixture is explicitly Simulator/test-flag gated. |
| P0-05 | Persist account, plan and settings changes across relaunch | P0 | `DONE_VERIFIED` | Targeted iPhone 17e Simulator flow verified the created obligation and confirmed expected income after app relaunch. Existing account/transaction persistence UI test also passed on iPhone 17 Simulator. |
| P0-06 | Avoid false-safe advice with stale, missing, or unreliable data | P0 | `IMPLEMENTED_UNVERIFIED` | `FinanceEngine.checkPurchase` fails closed for absent, stale/future balance, unconfirmed income, unreliable history, and invalid plan data, with a reason string for each branch. A targeted native empty-data UI flow passed historically; stale native messaging has not been exercised on this change. |
| P1-01 | Import a statement with preview, deduplication, persistence and relaunch | P1 | `IMPLEMENTED_UNVERIFIED` | CSV parsing/import and historical simulator import/dedup flow exist; current system picker and bank-specific real statement remain unverified. |
| P1-02 | Edit/classify transactions and retain explicit category rules | P1 | `IMPLEMENTED_UNVERIFIED` | Source paths and core behavior exist; current native editing and rule persistence need verification. |
| P1-03 | Maintain budgets and see consistent category limits | P1 | `IMPLEMENTED_UNVERIFIED` | UI/core source exists; current SwiftData flow not freshly verified. |
| P1-04 | Maintain goals, debts, recurring obligations and avoid double counting | P1 | `IMPLEMENTED_UNVERIFIED` | Source and historical persistence tests exist; current edit/reconciliation/relaunch paths need verification. |
| P1-05 | Receive and cancel local reminders correctly | P1 | `IMPLEMENTED_UNVERIFIED` | Scheduling/cancellation was historically tested; actual presentation at trigger time and current runtime are unverified. |
| P1-06 | Hide amounts, protect app access, delete local data clearly | P1 | `IMPLEMENTED_UNVERIFIED` | Controls and deletion path exist; current uncommitted app-lock change is unverified; no claim of cryptographic erasure or deletion of external backups. |
| P2-01 | Use a coherent approved native design and accessible motion | P2 | `PARTIAL` | Design system and visual materials exist; design gates/DA-01…DA-25 and full native accessibility acceptance remain incomplete. |
| P2-02 | Use Orbit O startup animation integrated with readiness | P2 | `IMPLEMENTED_UNVERIFIED` | Supplied SwiftUI component is compiled in the app target, receives mounted-root readiness and is removed by the host; generic iOS Simulator build and app launch pass. Integrated animation-frame fidelity, VoiceOver, Reduce Motion interaction and physical device remain unverified. |
| EXT-01 | Automatic bank sync without server/intermediary | P0 / external | `BLOCKED_EXTERNAL` | No bank-approved direct iOS route confirmed; CSV is not equivalent. No adapter may be fabricated. |
| FUT-01 | External AI financial assistant | Deferred | `DEFERRED` | Explicitly deferred by user. |
| FUT-02 | Family/shared budget, payments, multi-currency, voice input | Rejected/deferred | `REJECTED` | Outside agreed MVP scope in `PRODUCT_SPEC.md`. |

Do not turn a row into `DONE_VERIFIED` from source inspection or core tests alone. Evidence must match the user result and persistence claims.
