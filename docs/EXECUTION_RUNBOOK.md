# CRIP_BOT Execution Runbook

## Scope

CRIP_BOT is an original implementation of the same broad objective as the reference `flashloaner-contract`: atomic Uniswap-V2-compatible flash-swap execution followed by a swap route and same-transaction settlement.

This runbook deliberately uses real protocol deployments and forked networks for integration validation. It does not prescribe mock-protocol deployment.

## 1. Install

Required tooling:

- Git
- Foundry (`forge`, `cast`, `anvil`)
- A funded development/testnet signer only when broadcasting
- An RPC endpoint for the selected chain

```bash
git clone https://github.com/Samoolino/CRIP_BOT.git
cd CRIP_BOT
git submodule update --init --recursive
forge build
```

Never commit `.env` or private keys.

## 2. Configure

Copy `.env.example` to `.env` and provide the selected deployment's RPC, factory, router, pair, token addresses and execution thresholds.

The contract should only be configured against addresses that have been independently inspected on the selected network.

## 3. Inspect the real pair

Before deployment, verify:

```bash
cast call $V2_PAIR "factory()(address)" --rpc-url $RPC_URL
cast call $V2_PAIR "token0()(address)" --rpc-url $RPC_URL
cast call $V2_PAIR "token1()(address)" --rpc-url $RPC_URL
cast call $V2_PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL
```

The factory returned by the pair must equal the configured factory.

## 4. Quote repayment

Use the quote script to calculate the required opposite-side repayment for both possible borrow directions. V2 flash-swap repayment must be computed from the reserves after the outgoing borrow and must round upward.

## 5. Fork validation

Start a fork from the exact RPC/network configuration:

```bash
anvil --fork-url "$RPC_URL"
```

Run the Foundry scripts against the fork. Validate the complete call path using the actual pair, router and token contracts.

Required evidence before any testnet broadcast:

- callback caller is the expected pair;
- pair factory is the expected factory;
- router is the intended router;
- borrow token and route are compatible;
- repayment is sufficient;
- minimum profit remains after the route;
- transaction simulation succeeds.

## 6. Deployment

Dry-run first:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL"
```

Broadcast only after inspecting the resulting transaction and addresses:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
```

Record the deployed executor address and deployment transaction hash outside source control.

## 7. Execution strategy

The off-chain opportunity engine must calculate:

`expected output - flash-swap repayment - DEX fees - gas - slippage allowance - safety margin`

An opportunity is executable only if the resulting net profit exceeds the configured minimum.

The bot should simulate immediately before signing. Quotes are perishable; a quote from an earlier block is not a guarantee of execution profitability.

## 8. Transaction lifecycle

```text
opportunity discovery
        -> quote
        -> repayment calculation
        -> gas estimation
        -> net-profit gate
        -> simulation
        -> sign
        -> execute()
        -> pair sends borrowed token
        -> uniswapV2Call()
        -> validate callback
        -> router swap
        -> calculate repayment
        -> verify minimum profit
        -> repay pair
        -> transfer surplus
```

## 9. Failure handling

Any failed atomic execution must revert rather than leaving an unpaid flash swap. The bot should treat failed simulations and reverted transactions as execution failures, not as signals to increase risk automatically.

If market conditions change between simulation and inclusion, the transaction should fail the on-chain minimum-profit/slippage protections rather than executing an uneconomic route.

## 10. Production controls

Before live use:

1. Use a dedicated signer.
2. Restrict the signer to the minimum required role.
3. Keep private keys in a secrets manager or protected runtime environment.
4. Set conservative per-transaction and daily risk limits off-chain.
5. Monitor reverted and successful transactions.
6. Monitor executor balances and unexpected token transfers.
7. Keep a deployment manifest containing chain ID, factory, router, pair and executor addresses.

## 11. Ending an execution session

```text
stop opportunity scanner
        -> stop new transaction submission
        -> wait for pending transactions
        -> inspect executor balances
        -> record transaction hashes/logs
        -> disable signer/session
```

## 12. Emergency stop

The first response to anomalous pricing, unexpected callbacks, abnormal gas behavior or unexpected token movement is to stop the off-chain transaction signer/scanner. Do not attempt ad-hoc recovery transactions without first identifying the cause.

## 13. What is intentionally not automated yet

No production private key, live deployment address, or mainnet execution target is embedded in this repository. Chain-specific configuration must be selected and verified before deployment.
