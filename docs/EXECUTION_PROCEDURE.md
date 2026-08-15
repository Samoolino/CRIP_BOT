# CRIP_BOT execution procedure

## 1. Objective

Operate the same basic objective as `pedrobergamini/flashloaner-contract`: obtain liquidity through a V2-compatible flash swap, execute an atomic route, repay the originating pair, and retain only the verified surplus.

## 2. Repository structure

CRIP_BOT follows the reference repository's operational structure without development mocks:

```text
src/
  FlashSwapExecutor.sol
  interfaces/
    IERC20.sol
    IV2Pair.sol
    IV2Router02.sol
  libraries/
    V2Math.sol
script/
  DeployExecutor.s.sol
  QuoteRepayment.s.sol
  InspectPair.s.sol
  SimulateFork.s.sol
test/
  FlashSwapExecutor.t.sol
  FlashSwapExecutor.fuzz.t.sol

docs/
  REFERENCE_AUDIT.md
  EXECUTION_PROCEDURE.md
foundry.toml
.env.example
```

The `test` directory is reserved for protocol-integration and fork tests. There are no fake production endpoints or mock DEX contracts.

## 3. Installation

Install Git, Rust and Foundry on the development machine. Verify:

```bash
forge --version
cast --version
anvil --version
```

Clone the destination repository:

```bash
git clone https://github.com/Samoolino/CRIP_BOT.git
cd CRIP_BOT
```

Install Solidity dependencies:

```bash
forge install
```

Compile:

```bash
forge build
```

Format:

```bash
forge fmt --check
```

## 4. Environment configuration

Create a local environment file from `.env.example`.

Required classes of configuration are:

- RPC endpoint for the selected network.
- Deployer/signer key supplied by the runtime secret store.
- V2 factory address.
- V2 router address.
- Real pair address.
- Base/borrow token and route token addresses.

Never commit a private key, seed phrase, authenticated RPC URL, or API secret.

## 5. Ignition / deployment model

Deployment is performed by a Foundry script, following the reference repository's `script/DeployFlashLoaner.s.sol` approach.

The sequence is:

1. Select the network RPC.
2. Load factory/router addresses from environment configuration.
3. Broadcast deployment with a controlled signer.
4. Construct `FlashSwapExecutor(factory, router)`.
5. Query and validate the intended pair against the factory.
6. Call `configurePair(realPair)`.
7. Record deployed executor and configuration addresses in deployment notes.
8. Do not execute arbitrage during deployment.

Example dry-run pattern:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL"
```

Broadcast only after review:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
```

## 6. Pair inspection before execution

Before the executor is configured, inspect the real pair:

```bash
cast call $PAIR "factory()(address)" --rpc-url "$RPC_URL"
cast call $PAIR "token0()(address)" --rpc-url "$RPC_URL"
cast call $PAIR "token1()(address)" --rpc-url "$RPC_URL"
cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url "$RPC_URL"
```

The returned factory must match the executor's configured factory.

## 7. Repayment calculation

For a single-sided V2 flash swap, the repayment is calculated from the reserves before the swap. For a borrow of token0:

`repaymentToken1 = ceil(amount0Out * reserve1 * 1000 / ((reserve0 - amount0Out) * 997))`

For a borrow of token1:

`repaymentToken0 = ceil(amount1Out * reserve0 * 1000 / ((reserve1 - amount1Out) * 997))`

The execution must not rely on a caller-supplied repayment figure.

## 8. Opportunity procedure

The bot first obtains fresh quotes from the selected venues.

For each candidate:

1. Read current pair reserves/quotes.
2. Determine the borrow amount.
3. Determine the round-trip route.
4. Calculate required repayment.
5. Estimate final returned amount.
6. Estimate gas.
7. Add slippage and execution safety margin.
8. Require net profit above policy minimum.
9. Simulate the transaction against the latest state.
10. Submit only when the simulation succeeds and the opportunity remains profitable.

The important calculation is:

`netProfit = expectedReturn - repayment - swapCosts - gasCost - safetyMargin`

## 9. Execution

The executor call is conceptually:

```text
execute(
  borrowToken,
  amount,
  [borrowToken, intermediateToken, borrowToken],
  minProfit
)
```

The contract calls the configured V2 pair.

The pair transfers the borrowed side to the executor and invokes `uniswapV2Call`.

The callback verifies:

- callback caller is the configured pair;
- callback sender is the executor itself;
- exactly one borrow side is non-zero;
- borrowed token matches pair token ordering;
- callback amount matches the requested amount;
- route begins and ends with the borrowed token.

The executor then approves the configured router, performs the route, calculates repayment, checks the profit floor, repays the pair, and sends verified surplus to the owner.

## 10. Fork validation instead of mocks

Use Anvil fork mode for integration validation:

```bash
anvil --fork-url "$RPC_URL"
```

Point Foundry tests/scripts to the local fork endpoint and verify against actual deployed protocol contracts.

Minimum fork scenarios:

- profitable round trip;
- unprofitable round trip;
- insufficient liquidity;
- stale quote;
- excessive borrow size;
- router revert;
- slippage beyond policy;
- wrong pair/factory;
- callback authentication failure.

## 11. Mainnet/testnet ignition sequence

### Stage A — Compile

`forge build`

### Stage B — Static review

Review contract, interfaces, configuration and deployment addresses.

### Stage C — Fork simulation

Run the complete transaction against a fork at the intended block/state.

### Stage D — Testnet deployment

Deploy the exact artifact to the target test network.

### Stage E — Controlled transaction

Use a very small bounded borrow amount and manually inspect the transaction result, pair balances, executor balance and emitted event.

### Stage F — Monitoring

Monitor transaction hash, gas usage, repayment amount, profit and revert reasons.

### Stage G — Production activation

Only after the fork/testnet execution path is reproducible should the production signer be enabled.

## 12. Signer and key handling

The private key is a transaction credential, not a contract parameter. It belongs in the runtime environment or a dedicated secret manager. The bot uses it only to sign the transaction calling the deployed executor.

The executor itself should never contain or receive a private key.

## 13. Ending / shutdown procedure

When the trading process is stopped:

1. Stop opportunity submission.
2. Allow already-broadcast transactions to settle.
3. Confirm the executor has no unintended residual assets.
4. Withdraw verified accumulated profits if policy permits.
5. Disable the production signer from the bot runtime.
6. Preserve execution logs and transaction hashes for audit.
7. Keep the deployed contract address and artifact hash recorded.

For an emergency, the first operational response is to stop the off-chain signer/bot rather than attempting arbitrary contract calls.

## 14. Production operating rule

CRIP_BOT is not considered live merely because the contract is deployed. The live state is:

`scanner -> quote -> profitability -> simulation -> signed transaction -> atomic execution -> repayment -> profit -> monitoring`

Every stage must succeed before the system is considered operational.
