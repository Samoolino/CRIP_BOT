# Real V2 Fork Gate

This gate validates CRIP_BOT against real deployed protocol bytecode on a Foundry/Anvil fork. It does not deploy mock factories, pairs, routers, or tokens.

## Required GitHub Actions secrets

Set these repository secrets before manually dispatching `Real V2 Fork Gate`:

- `CRIP_RPC_URL`
- `CRIP_V2_FACTORY`
- `CRIP_V2_ROUTER`
- `CRIP_V2_PAIR`

The selected pair must report the configured factory through `factory()`.

## What the gate verifies

1. The configured factory, router and pair contain deployed bytecode on the selected fork.
2. The pair reports the configured factory.
3. The pair exposes two distinct non-zero token addresses.
4. The pair has non-zero reserves at the forked state.
5. `FlashSwapExecutor` can be deployed against the selected factory/router.
6. The real pair can be configured in the executor.

This is a deployment/configuration gate, not yet a profitable arbitrage execution test. It deliberately stops short of signing or broadcasting a live transaction.

## Manual execution

GitHub Actions → **Real V2 Fork Gate** → **Run workflow**.

The workflow uses the configured RPC endpoint and real protocol addresses only through GitHub Secrets.

## Next gate

After this inspection passes, add a route-specific real-protocol fork test for a selected pair/router/token path. That test must establish the route's `amountOutMin`, repayment amount and minimum-profit requirement from the same fork state before attempting the atomic callback.
