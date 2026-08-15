# Sepolia Real-Protocol Fork Procedure

## Reference deployment

The repository pins the official Uniswap V2 Sepolia factory and Router02 in `config/uniswap-v2-sepolia-reference.json`.

The pair is intentionally not hard-coded. Discover it from the real factory with `DiscoverPair.s.sol` after selecting two independently verified token addresses.

## Configuration

Start from `config/fork-sepolia.example.env` and supply:

- `RPC_URL` — a Sepolia RPC endpoint;
- `V2_FACTORY` — pinned reference factory;
- `V2_ROUTER` — pinned reference Router02;
- `V2_PAIR` — discovered and independently verified pair;
- `BORROW_TOKEN` — one of the pair assets;
- `INTERMEDIATE_TOKEN` — route token;
- `BORROW_AMOUNT_WEI` — bounded test amount;
- `MIN_PROFIT_WEI` — minimum new profit for simulation;
- `SLIPPAGE_BPS` — explicit slippage policy;
- `DEADLINE_SECONDS` — short execution window;
- `EXECUTE_FORK=false` until inspection and quote gates pass.

Never place RPC credentials or private keys in this file or in Git history.

## Discovery

Use the real factory to resolve the pair:

```bash
forge script script/DiscoverPair.s.sol --rpc-url "$RPC_URL" --sig "run(address,address,address)" "$V2_FACTORY" "$TOKEN_A" "$TOKEN_B"
```

The discovered pair must satisfy:

```text
pair != 0x0
pair.factory() == V2_FACTORY
token0/token1 == requested token set
reserve0 > 0
reserve1 > 0
```

## Fork validation

Create a local Anvil fork from the same RPC endpoint:

```bash
anvil --fork-url "$RPC_URL"
```

Run the deployment-inspection and router-quote tests against the fork. Preserve the block number and reserve snapshot in the fork evidence record.

## Atomic fork execution gate

Only after inspection and route quote are successful should the execution-only fork test be enabled with:

```text
EXECUTE_FORK=true
```

The execution test remains a fork simulation. It does not use a production signer or broadcast to the public network.

## Release boundary

A successful Sepolia fork run is evidence that the selected real deployment path is internally coherent. It is not proof of profitability on a live market and does not authorize mainnet trading.
