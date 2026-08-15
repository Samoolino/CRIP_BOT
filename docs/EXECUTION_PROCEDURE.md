# CRIP_BOT execution procedure

## Objective

Operate the same basic objective as the reference flashloaner: obtain liquidity through a V2-compatible flash swap, execute an atomic route, repay the originating pair, and retain only verified surplus.

## Installation

```bash
git clone https://github.com/Samoolino/CRIP_BOT.git
cd CRIP_BOT
git submodule update --init --recursive
forge build
forge fmt --check
```

Create `.env` from `.env.example`. Keep secrets out of Git.

## Real deployment configuration

Provide only independently verified values for:

- RPC endpoint;
- V2 factory;
- V2 router;
- real V2 pair;
- borrow token;
- route tokens;
- minimum profit;
- borrow amount policy.

Before configuration, inspect the real pair and verify `pair.factory()` equals the configured factory.

## Deployment

Dry run:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL"
```

Broadcast only after address review:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
```

Record the executor address and deployment transaction hash outside source control.

## Economic procedure

For a single-sided V2 flash swap, borrowing token0 requires repayment in token1; borrowing token1 requires repayment in token0. Repayment is calculated from current reserves and rounded upward.

For each opportunity:

1. Obtain fresh quotes.
2. Select borrow amount.
3. Determine route.
4. Calculate flash-swap repayment.
5. Calculate router output.
6. Calculate `amountOutMin` from the allowed slippage.
7. Calculate gas and all known fees.
8. Require net profit above policy minimum.
9. Simulate against current state.
10. Sign only if simulation remains profitable.

Conceptually:

`netProfit = expectedReturn - repayment - swapCosts - gasCost - safetyMargin`

## Atomic execution

```text
execute()
  -> source pair sends borrowed asset
  -> callback authenticates pair and sender
  -> validate borrow amount and route
  -> record repayment-token balance
  -> router swap with amountOutMin + deadline
  -> calculate V2 repayment
  -> verify newly received repayment balance
  -> enforce minimum profit
  -> repay source pair
  -> transfer verified surplus
```

If any condition fails, the transaction reverts atomically.

The route must start with the borrowed token and end with the opposite asset of the source pair. This is the repayment asset for the single-sided V2 flash swap.

## Fork validation — no protocol mocks

Use a fork of the selected real deployment:

```bash
anvil --fork-url "$RPC_URL"
```

Integration validation must use the real pair, router and token contracts. Required scenarios include profitable execution, insufficient liquidity, excessive borrow size, router revert, stale quote, slippage breach, wrong pair/factory and callback authentication failure.

## Production controls

The off-chain engine must enforce transaction-size and daily risk limits, current-block quote freshness, gas-aware profitability, explicit slippage, and immediate pre-sign simulation.

The private key remains runtime-only and must be stored outside the repository.

## Shutdown

1. Stop opportunity submission.
2. Allow pending transactions to settle.
3. Inspect executor balances.
4. Withdraw verified profits if policy permits.
5. Disable the production signer.
6. Preserve transaction hashes and logs.
7. Record deployment/artifact information for audit.

For an emergency, stop the off-chain signer/scanner first. Do not issue arbitrary recovery transactions without diagnosing the failure.
