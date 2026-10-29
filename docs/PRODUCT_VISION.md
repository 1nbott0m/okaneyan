# MoneyWise product vision

MoneyWise is a Russian-language native iPhone financial navigator. Its central job is to help a person understand what can be spent now without putting necessary expenses and future plans at risk. It explains the result in concrete amounts and dates, supports thoughtful purchases, and never shames the user.

The product is local-first, works without an account, and uses deterministic financial calculations. The main experience connects confirmed balances, dated obligations, protected reserves, goals, forecasts, and purchase checks. Unknown or stale information must be visible and must not produce false certainty.

The original first user is the project owner, with a design that can serve other individuals. Shared family budgeting is outside the agreed scope. The product is native SwiftUI; `preview/index.html` is a synthetic-data review surface only.

Automatic bank updates remain a desired requirement, subject to a strict user constraint: direct bank-approved iOS access only, with no backend, intermediary, aggregator, scraping, or bank-password collection. CSV is a fallback and does not satisfy automatic synchronization. External AI is deferred.

See [PRODUCT_SPEC.md](../PRODUCT_SPEC.md) for the functional contract, [REQUIREMENTS_STATUS.md](REQUIREMENTS_STATUS.md) for evidence-based status, and [DECISIONS.md](DECISIONS.md) for decisions and unresolved conflicts.
