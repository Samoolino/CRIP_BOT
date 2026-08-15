# Real V2 Fork Gate

This gate validates CRIP_BOT against real deployed protocol bytecode on a Foundry/Anvil fork. It does not deploy mock factories, pairs, routers, or tokens.

## Deployment selection

For an existing pair, prefer the real factory `getPair(tokenA, tokenB)` lookup instead of hard-coding an unverified pair address. `script/DiscoverPair.s.sol` performs this read-only discovery and then verifies the returned pair's factory, token ordering and non-zero reserves.

The canonical Uniswap V2 documentation identifies `getPair` as the direct on-chain way to determine whether a pair exists. The Ethereum V2 factory and Router02 addresses are maintained in Uniswap's deployment documentation.

## Required GitHub Actions secrets

Set these repository secrets before manually dispatching **Real V2 Fork Gate**:

- `CRIP_RPC_URL` — RPC endpoint for the selected chain.
- `CRIP_V2_FACTORY` — verified V2-compatible factory address.
- `CRIP_V2_ROUTER` — verified router address for the selected deployment.
- `CRIP_V2_PAIR` — verified source pair address.

### Optional route-quote secrets

For the route quote stage, additionally set:

- `CRIP_BORROW_TOKEN`
- `CRIP_INTERMEDIATE_TOKEN`
- `CRIP_BORROW_AMOUNT_WEI`

The selected pair must report the configured factory through `factory()`. The factory, router, and pair must all contain deployed bytecode on the selected fork.

## What the gate verifies

### Stage 1 — deployment inspection

1. Factory, router and pair contain deployed bytecode on the selected fork.
2. Pair reports the configured factory.
3. Pair exposes two distinct non-zero token addresses.
4. Pair has non-zero reserves at the forked state.
5. `FlashSwapExecutor` can be deployed against the selected factory/router.
6. The real pair can be configured in the executor.

### Stage 2 — optional route quote

When the optional route-quote secrets are present, the fork test additionally verifies:

1. Borrow token is one of the pair assets.
2. Intermediate token is distinct from the pair assets.
3. Router accepts the three-hop path.
4. Router returns a quote from the forked state.
5. The returned input amount equals the requested borrow amount.
6. The quoted repayment-side output is non-zero.

This stage is still **quote-only**. It does not approve tokens, call `execute()`, sign a transaction, or broadcast anything.

## Pair discovery procedure

For a selected token pair:

```bash
forge script script/DiscoverPair.s.sol \
  --sig "run(address,address,address)" \
  "$V2_FACTORY" "$TOKEN_A" "$TOKEN_B" \
  --rpc-url "$RPC_URL"
```

The script checks:

- pair exists;
- pair factory matches the selected factory;
- pair contains exactly the requested two assets;
- both reserves are non-zero.

Record the returned pair address in the protected fork configuration only after independent verification.

## Manual execution

GitHub Actions → **Real V2 Fork Gate** → **Run workflow**.

The workflow performs configuration preflight, installs Foundry standard library, runs formatting/build checks, performs real deployment inspection, and optionally performs the real-router quote stage.

## Evidence to preserve

For an accepted run, record the workflow run, selected chain/network, pair/factory/router addresses, pair token addresses, reserve snapshot, route (where enabled), quoted output, and resulting CRIP_BOT executor configuration. These become part of the deployment manifest for the next gate.

## Release boundary

Passing this gate does **not** authorize production trading. The next execution gate must establish `amountOutMin`, V2 repayment, minimum profit, and exact route from the same fork state before attempting atomic callback execution. That execution test remains simulation-only until separately approved for testnet use.
