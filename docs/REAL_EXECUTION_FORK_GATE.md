# Real Atomic Execution Fork Gate

This is the final pre-testnet contract execution gate for CRIP_BOT. It runs the complete V2 flash-swap lifecycle against real deployed protocol bytecode on a Foundry fork.

## Required secrets

Core:

- `CRIP_RPC_URL`
- `CRIP_V2_FACTORY`
- `CRIP_V2_ROUTER`
- `CRIP_V2_PAIR`
- `CRIP_BORROW_TOKEN`
- `CRIP_INTERMEDIATE_TOKEN`
- `CRIP_BORROW_AMOUNT_WEI`
- `CRIP_MIN_PROFIT_WEI`
- `CRIP_SLIPPAGE_BPS`
- `CRIP_DEADLINE_SECONDS`
- `CRIP_EXECUTE_FORK=true`

## What the execution fork verifies

1. The configured pair exists on the fork.
2. The pair belongs to the configured factory.
3. Borrow amount is below the live fork reserve for the selected borrow asset.
4. The selected route begins with the borrowed asset and ends with the pair's opposite asset.
5. The real router returns a quote for that route.
6. V2 repayment is calculated from the same fork reserves.
7. The quote exceeds repayment plus the configured minimum-profit floor.
8. `amountOutMin` is derived from the forked quote and configured slippage basis points.
9. The executor is deployed and configured against the real factory/router/pair.
10. `execute()` is called entirely inside the fork simulation.
11. The transaction completes only if the pair is repaid and the executor forwards verified surplus.

## Important boundary

This workflow never uses a production private key and never broadcasts a network transaction. `execute()` runs inside the forked EVM only.

A successful fork execution proves the chosen route can settle atomically against the selected fork state. It does not prove that the same opportunity will remain profitable on a future live block.

## Release decision

Do not proceed to testnet until the fork evidence is recorded, including:

- chain/network;
- fork block;
- factory/router/pair;
- token0/token1;
- reserves;
- borrow amount;
- route;
- quote;
- repayment;
- amountOutMin;
- minimum profit;
- simulated execution result;
- executor artifact/commit;
- workflow run ID.

Testnet then uses the exact reviewed artifact and bounded transaction policy. Production remains disabled until testnet behavior is reproducible and independently reviewed.
