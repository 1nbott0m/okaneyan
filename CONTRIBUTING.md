# Contributing

Thanks for helping build okaneyan. This repository has three workstreams—product and financial core, native product design, and brand/motion—but they contribute to **one native iOS product** and one shared `main` branch.

Before starting, read [AGENTS.md](AGENTS.md), [PRODUCT_SPEC.md](PRODUCT_SPEC.md), [DESIGN.md](DESIGN.md), and the relevant project documents. Follow the branch, worktree, commit, privacy, and pull request process in the [GitHub workflow](docs/development/github-workflow.md). Do not commit chat transcripts, real financial exports, local databases, secrets, signing material, or unreviewed device screenshots.

The SwiftUI iOS app is the production implementation. `Sources/MoneyCore/` owns financial calculations. `preview/` is a review surface with labeled synthetic data; it is not a second production app. Design and brand proposals become product work only after their direction and behavior are accepted and integrated through a focused pull request.
