# Chain Selection Gate

CRIP_BOT does not hard-code a production network. A chain is admitted to the fork gate only after its V2-compatible deployment is independently verified.

## Required evidence

Record these values in the deployment manifest used for the audit:

- Chain name and chain ID.
- RPC provider/source.
- V2 factory address.
- V2 router address.
- V2 pair address.
- Pair `token0` and `token1`.
- Pair reserves at the selected block.
- Selected block number/hash.
- Verification source for each contract address.

## Acceptance tests

1. `factory.code.length > 0`.
2. `router.code.length > 0`.
3. `pair.code.length > 0`.
4. `pair.factory() == configured factory`.
5. `token0 != 0` and `token1 != 0`.
6. `token0 != token1`.
7. Both pair reserves are non-zero for the selected block.
8. The router is an intended V2-compatible router for the selected deployment.
9. The route assets are compatible with the selected pair.

## Freeze rule

Do not substitute a different factory, router, pair, token, or block after the fork evidence has been collected. Treat a changed address or block as a new deployment configuration and rerun the gate.

## Production boundary

Passing these checks proves only that the configured contracts exist and are internally consistent. It does not prove that an arbitrage is profitable or that the route is safe to execute. Route-level simulation remains a separate gate.
