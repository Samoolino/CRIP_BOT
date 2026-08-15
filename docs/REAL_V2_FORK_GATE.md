# Real V2 Fork Gate

This gate validates CRIP_BOT against real deployed protocol bytecode on a Foundry/Anvil fork. It does not deploy mock factories, pairs, routers, or tokens.

## Required GitHub Actions secrets

Set these repository secrets before manually dispatching **Real V2 Fork Gate**:

- `CRIP_RPC_URL` — RPC endpoint for the selected chain.
- `CRIP_V2_FACTORY` — verified V2-compatible factory address.
- `CRIP_V2_ROUTER` — verified router address for the selected deployment.
- `CRIP_V2_PAIR` — verified source pair address.

The selected pair must report the configured factory through `factory()`. The factory, router, and pair must all contain deployed bytecode on the selected fork.

## Configuration rule

Do not add RPC URLs, wallet private keys, or deployment addresses to source files merely to make the workflow pass. The workflow reads the above values from GitHub Actions Secrets. The manual workflow now fails immediately when one of the four required secrets is missing.

## What the gate verifies

1. The configured factory, router and pair contain deployed bytecode on the selected fork.
2. The pair reports the configured factory.
3. The pair exposes two distinct non-zero token addresses.
4. The pair has non-zero reserves at the forked state.
5. `FlashSwapExecutor` can be deployed against the selected factory/router.
6. The real pair can be configured in the executor.

This is a deployment/configuration gate, not yet a profitable arbitrage execution test. It deliberately stops short of signing, broadcasting, or transferring funds.

## Manual execution

GitHub Actions → **Real V2 Fork Gate** → **Run workflow**.

The workflow performs a configuration preflight, installs the Foundry standard library, runs formatting/build checks, and then executes `test/FlashSwapExecutor.fork.t.sol` against the configured fork.

## Evidence to preserve

For an accepted fork run, record the workflow run, selected chain/network, pair/factory/router addresses, pair token addresses, reserve snapshot, and resulting CRIP_BOT executor configuration. These become part of the deployment manifest for the next gate.

## Next gate

After this inspection passes, add a route-specific real-protocol fork test for a selected pair/router/token path. That test must establish the route's `amountOutMin`, V2 repayment amount, and minimum-profit requirement from the same fork state before attempting the atomic callback. That execution test remains simulation-only until separately approved for testnet use.
