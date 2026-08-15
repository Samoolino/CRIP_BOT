# CRIP_BOT — V2 Fork Security Audit

## Scope

This review covers the no-mock V2 flash-swap executor and its real-protocol fork validation path.

## Security invariants

1. **Owner authorization** — only the deployment owner can configure the approved pair, execute a swap, or withdraw tokens.
2. **Pair identity** — the configured pair must report the configured factory, and the factory must map the pair's two tokens back to the same pair.
3. **Callback authentication** — the callback accepts only the configured pair and requires `sender == address(this)`.
4. **Execution lock** — the callback is only valid while an owner-initiated execution is active.
5. **Borrow-asset binding** — the callback amount and token must match the asset actually emitted by the pair.
6. **Route binding** — the path must begin with the borrowed asset and end with the pair's repayment asset.
7. **Reserve-domain repayment** — repayment math uses the pair's actual `uint112` reserves and rejects borrowing at or above the borrowed reserve.
8. **Slippage floor** — `amountOutMin` must be non-zero and is enforced by the router call.
9. **Deadline** — execution and callback reject expired deadlines.
10. **Profit floor** — post-swap repayment-asset balance must cover the required repayment plus `minProfit`; only the new surplus is transferred to the owner.
11. **No production credentials in source** — RPC endpoints, secrets, and signing keys remain outside repository source.
12. **Fork-only execution stage** — the atomic execution harness is invoked only by the explicitly dispatched fork workflow.

## Hardening applied

`configurePair()` now requires both:

```text
pair.factory() == configured factory
factory.getPair(token0, token1) == pair
```

This prevents a deployment from accepting a pair that merely claims the factory while not being the factory's canonical pair for those assets.

## Known release blocker

A passing baseline CI suite is not equivalent to a real-protocol execution proof. The release candidate remains blocked until the protected `Real V2 Fork Gate` produces an actual successful run with verified chain-specific configuration.

## Test boundaries

- Baseline CI: formatting, compilation, unit/fuzz tests, configuration-shape checks.
- Public deployment preflight: read-only verification of documented deployment bytecode/metadata.
- Real V2 Fork Gate: real factory/router/pair inspection, pair discovery, router quote, and opt-in atomic fork execution.
- No live-network broadcast is part of the fork acceptance gate.

## Release decision

`BLOCKED_PENDING_REAL_FORK_EVIDENCE`
