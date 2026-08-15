# Real V2 Fork Gate — Acceptance Status

## Baseline CI

Verified on commit `afe846e78f53da21d50443973792b279b816a2d4`:

- Foundry CI: passed
- Reference Profile Check: passed
- Public V2 Deployment Preflight: passed

## Real-fork acceptance

The dedicated workflow is `.github/workflows/real-v2-fork.yml` and is intentionally `workflow_dispatch` only.

Required protected configuration:

- `CRIP_RPC_URL`
- `CRIP_V2_FACTORY`
- `CRIP_V2_ROUTER`
- `CRIP_BORROW_TOKEN`
- `CRIP_REPAYMENT_TOKEN`

Optional/conditional:

- `CRIP_V2_PAIR` — discovered from the factory when omitted
- `CRIP_INTERMEDIATE_TOKEN`
- `CRIP_BORROW_AMOUNT_WEI`
- `CRIP_MIN_PROFIT_WEI`
- `CRIP_SLIPPAGE_BPS`
- `CRIP_DEADLINE_SECONDS`
- `CRIP_EXECUTE_FORK`

## Acceptance sequence

1. Validate protected configuration.
2. Discover/verify the real pair.
3. Inspect real factory/router/pair bytecode and metadata.
4. Run the real-router quote stage.
5. Run atomic fork execution only when `CRIP_EXECUTE_FORK=true`.
6. Record the GitHub Actions run as the fork evidence.

## Release boundary

No successful fork run means no testnet or production authorization.

This document does not contain RPC credentials, private keys, or live-execution authorization.
