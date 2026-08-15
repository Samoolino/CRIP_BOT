# CRIP_BOT

Original flash-swap arbitrage architecture using `pedrobergamini/flashloaner-contract` as the structural guide, but implemented as a separate codebase with deployment-aware validation, real-protocol fork testing, and explicit operational procedures.

## Objective

Perform atomic same-chain arbitrage using liquidity borrowed from a Uniswap V2-compatible pair, route the borrowed asset through an approved router, repay the originating pair in the same transaction, and retain only verified surplus.

## Reference approach

The reference repository is a Foundry project centered on `FlashLoaner.sol`. Its execution model is:

1. receive `uniswapV2Call`;
2. validate one-sided borrowing;
3. authenticate the pair against factory configuration;
4. identify the borrowed and repayment assets;
5. approve a router;
6. calculate V2 repayment from reserves;
7. perform the swap;
8. reject output below repayment;
9. repay the source pair;
10. forward surplus to the initiator.

CRIP_BOT keeps this transaction pattern while separating market discovery and transaction policy into the off-chain layer.

## No mocks

The repository intentionally does not use mock production protocols. Testing is performed against real deployed protocol contracts through Anvil/Foundry forks and, later, controlled testnet deployments.

## Architecture

```text
Market/DEX data
      |
      v
Opportunity Scanner
      |
      v
Quote + Repayment Model
      |
      v
Gas / Slippage / Net-PnL Gate
      |
      v
Fork Simulation / eth_call
      |
      v
Transaction Signer
      |
      v
FlashSwapExecutor
      |
      v
V2 Pair -> callback -> approved router -> repay -> profit
```

## Repository structure

```text
CRIP_BOT/
├── src/
│   ├── FlashSwapExecutor.sol
│   ├── interfaces/
│   │   ├── IERC20.sol
│   │   ├── IV2Pair.sol
│   │   └── IV2Router02.sol
│   └── libraries/
│       └── V2Math.sol
├── script/
│   ├── DeployExecutor.s.sol
│   ├── QuoteRepayment.s.sol
│   ├── InspectPair.s.sol
│   └── SimulateFork.s.sol
├── test/
│   ├── FlashSwapExecutor.t.sol
│   └── FlashSwapExecutor.fork.t.sol
├── docs/
│   ├── REFERENCE_AUDIT.md
│   └── EXECUTION_PROCEDURE.md
├── foundry.toml
└── .env.example
```

## Installation

```bash
forge --version
cast --version
anvil --version

git clone https://github.com/Samoolino/CRIP_BOT.git
cd CRIP_BOT
forge install
forge build
forge fmt --check
```

## Ignition / deployment flow

The deployment process follows the reference repository's Foundry-script pattern:

```text
Select network
   -> load RPC/configuration
   -> dry-run deployment
   -> broadcast deployment
   -> inspect deployed executor
   -> verify real factory/pair relationship
   -> configure pair
   -> record address + artifact hash
   -> do not trade during deployment
```

Dry run:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL"
```

Broadcast only after review:

```bash
forge script script/DeployExecutor.s.sol --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --broadcast
```

## Execution strategy

The off-chain bot does not submit every apparent price difference. A candidate is executed only when:

```text
expected_return
- flash-swap_repayment
- swap_fees
- gas_cost
- slippage_allowance
- safety_margin
> minimum_net_profit
```

The sequence is:

```text
discover -> quote -> calculate repayment -> estimate gas
-> calculate net PnL -> simulate -> sign -> submit -> monitor
```

## Security model

The contract enforces:

- owner-only initiation;
- one configured real pair;
- factory relationship validation;
- callback-caller authentication;
- callback-sender authentication;
- one-sided borrowing;
- borrow-token/path validation;
- router restriction;
- exact V2 flash-swap repayment mathematics;
- minimum profit enforcement;
- profit forwarding only after repayment;
- no private key handling in the contract.

The reference implementation's fixed V2 `INIT_CODE_HASH` is treated as deployment-specific and is not copied as a universal constant.

## Operational stages

**Stage A:** compile and static review.

**Stage B:** inspect real factory/router/pair addresses.

**Stage C:** run fork simulations against actual protocol bytecode.

**Stage D:** deploy exact artifact to testnet.

**Stage E:** run bounded controlled transactions.

**Stage F:** activate monitored opportunity scanning.

**Stage G:** enable production signing only after the complete path is reproducible.

See `docs/EXECUTION_PROCEDURE.md` for the installation, ignition, execution, signer, monitoring and shutdown procedures.

## Ending / shutdown

To stop the system safely:

1. stop opportunity submission;
2. let already-broadcast transactions settle;
3. inspect executor balances;
4. withdraw verified profits where appropriate;
5. disable the signing key from the runtime;
6. preserve transaction hashes and logs;
7. keep the deployed address and artifact hash for audit.

## Production rule

Deployment alone does not constitute a live trading system. CRIP_BOT is operational only when the entire path is functioning:

`scanner -> quote -> profitability -> simulation -> signing -> atomic execution -> repayment -> profit -> monitoring`.
