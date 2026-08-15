# CRIP_BOT

Original flash-swap arbitrage architecture inspired by the objective of `pedrobergamini/flashloaner-contract`, but implemented as a separate codebase with stronger validation boundaries and an explicit separation between execution, opportunity detection, and configuration.

## Objective

Provide a test-first framework for atomic same-chain arbitrage using liquidity borrowed from a Uniswap V2-compatible pair, executing a configurable swap route, repaying the pair within the same transaction, and forwarding only verified surplus to the strategy owner/initiator.

## Reference audit

The reference repository is a Foundry project centered on `FlashLoaner.sol`. Its core callback:

1. receives a Uniswap V2 flash-swap callback;
2. validates that only one borrow side is non-zero;
3. reconstructs the expected pair address from the configured factory and a fixed init-code hash;
4. swaps the borrowed asset through one router;
5. calculates the repayment needed using V2 reserve math;
6. requires the swap proceeds to cover repayment;
7. repays the originating pair and forwards profit.

The reference also includes mocks, fuzz tests, deployment, simulation, and repayment-quote scripts.

## CRIP_BOT design principles

- **Atomic settlement:** an execution is successful only when the original liquidity source can be repaid in the same transaction.
- **Explicit trust boundaries:** the configured factory, callback caller, router, token path, and initiator are validated rather than inferred from loosely trusted calldata.
- **No live-key material in source:** secrets belong in deployment/runtime secret managers, never Git.
- **Testnet-first:** fork tests and mock tests must pass before any live-network deployment.
- **Profit floor:** every execution has a minimum acceptable net surplus requirement.
- **Deterministic route validation:** arbitrary call targets are not exposed in the first version.
- **Separation of concerns:** Solidity handles atomic execution; the off-chain bot handles discovery, simulation, gas estimation, and submission policy.

## Target architecture

```text
                    +---------------------------+
                    |  Market / Opportunity     |
                    |  Scanner + Quote Engine    |
                    +-------------+-------------+
                                  |
                                  | candidate route
                                  v
                    +---------------------------+
                    |  Risk / Profit Gate       |
                    |  gas + slippage + minPnL  |
                    +-------------+-------------+
                                  |
                                  | validated intent
                                  v
+----------------+      +---------------------------+
| V2 Pair /      |----->| CRIP_BOT Executor         |
| Liquidity Src  | cb   | atomic callback + swaps  |
+----------------+      +-------------+-------------+
                                      |
                                      | repay
                                      v
                              +---------------+
                              | Origin Pair   |
                              +---------------+
                                      |
                                      | surplus
                                      v
                              +---------------+
                              | Treasury /    |
                              | Initiator     |
                              +---------------+
```

## Planned repository layout

```text
CRIP_BOT/
├── src/
│   ├── FlashSwapExecutor.sol
│   ├── libraries/
│   │   └── V2Math.sol
│   └── interfaces/
│       ├── IERC20.sol
│       ├── IV2Pair.sol
│       └── IV2Router02.sol
├── test/
│   ├── FlashSwapExecutor.t.sol
│   └── mocks/
├── script/
│   ├── DeployExecutor.s.sol
│   └── QuoteRepayment.s.sol
├── bot/
│   ├── scanner/
│   ├── simulator/
│   ├── executor/
│   └── risk/
├── docs/
│   ├── REFERENCE_AUDIT.md
│   ├── THREAT_MODEL.md
│   └── ARCHITECTURE.md
├── foundry.toml
└── .env.example
```

## Security gates before mainnet

1. Unit tests and fuzz tests pass.
2. Invariant tests prove no successful execution leaves the executor unable to settle the source pair.
3. Fork tests validate real router/pair behavior against the selected deployment.
4. Static analysis and manual review are clean.
5. Deployment addresses are immutable/configured per network.
6. Private keys are injected through a secrets manager or CI secret store.
7. Mainnet execution starts with low-value, bounded transactions and monitoring.

## Important limitation of the reference implementation

The reference library derives V2 pairs using a fixed `INIT_CODE_HASH`. That is valid only for a deployment whose pair bytecode hash matches the configured constant. CRIP_BOT will treat pair derivation as a deployment-specific configuration and will prefer explicit factory verification, eliminating accidental use of a mismatched hash.

## Development order

**Phase 1:** reference audit + threat model.

**Phase 2:** minimal executor + mocks + unit/fuzz tests.

**Phase 3:** fork testing against a selected V2 deployment.

**Phase 4:** off-chain scanner, simulation, gas-aware profitability gate.

**Phase 5:** testnet deployment and monitored dry-run.

**Phase 6:** controlled production rollout after independent contract review.
