# Contributing to Codefone

Thanks for wanting to help — Codefone is a solo hobbyist project and outside eyes make it better.

## How to contribute

1. Open an issue first if the change is non-trivial. Small typo/doc fixes can go straight to a PR.
2. Fork the repo, make your change on a branch, open a pull request against `main`.
3. Keep PRs focused — one logical change per PR.
4. If you're changing a shell script, test it on a real Pixel running the current Linux Terminal Debian VM before submitting.

## Sign the Contributor License Agreement

**Before your first PR can be merged, you will need to sign the Codefone Contributor License Agreement (CLA).** See [`CLA.md`](CLA.md).

The CLA is automated — when you open your first PR, the CLA Assistant bot will post a comment with a link. Click it, sign once, and you're set for all future contributions.

### Why a CLA?

Codefone is dual-track:

- **Public source** under PolyForm Noncommercial 1.0.0 (free for personal / non-commercial use).
- **Private commercial license** available to companies that want to build products on it.

Without a CLA, every external contribution would lock the maintainer into only the public license for that piece of code. That would make commercial licensing impossible over time. The CLA solves this by letting you keep copyright of your contribution while granting Codefone permission to include it under both the public and commercial licenses.

You are **not** transferring ownership. You still own your code. You're giving Codefone permission to use it.

## What makes a good PR

- Clear description of what changed and why.
- If it changes behavior a user would notice, update the relevant `.md` doc in the same PR.
- Don't introduce new dependencies without discussing first — Codefone's value is "it just works on a stock phone."
- Respect the architecture decisions in [`DECISIONS.md`](DECISIONS.md). If you disagree with one, open an issue to discuss before coding around it.

## What NOT to contribute

- Commercial features, paid integrations, enterprise-only code — those belong in the separate commercial codebase, not this repo.
- Trademark-infringing forks, re-branded clones, or anything that violates [`TRADEMARKS.md`](TRADEMARKS.md).
- Code you didn't write yourself or have the right to contribute under the CLA.

## Code of conduct

Be decent. Don't be a jerk. Technical disagreement is fine; personal attacks are not. The maintainer reserves the right to close issues, reject PRs, and block users at his discretion.

## Contact

Questions that don't fit an issue: **joe@hx2o.com**
