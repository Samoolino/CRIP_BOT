# CRIP_BOT Security Checklist

## Contract boundary

- [x] Owner-gated execution.
- [x] Callback caller must equal configured pair.
- [x] Callback sender must equal executor.
- [x] Pair must report the configured factory.
- [x] Borrowed asset must be token0 or token1 of the configured pair.
- [x] Route begins with borrowed asset.
- [x] Route ends with the opposite pair asset.
- [x] Re-entrant execution state is blocked.
- [x] Pre-existing repayment-token balances are excluded from measured profit.
- [x] V2 repayment rounds upward.
- [x] Router is fixed at deployment.
- [x] Router output has an explicit `amountOutMin` floor.
- [x] Execution has an explicit deadline.

## Economic controls

- [ ] Quote is generated from the latest suitable block.
- [ ] Gas is included in off-chain net-profit calculation.
- [ ] DEX fees are included.
- [ ] Slippage tolerance is explicit.
- [ ] Minimum net profit is explicit.
- [ ] Opportunity is simulated immediately before signing.
- [ ] Transaction size and daily risk limits are enforced off-chain.

## Deployment

- [ ] Chain ID independently verified.
- [ ] Factory independently verified.
- [ ] Router independently verified.
- [ ] Pair factory matches configured factory.
- [ ] Token addresses independently verified.
- [ ] Deployment transaction recorded.
- [ ] Executor address recorded in deployment manifest.
- [ ] Private key stored outside Git.

## Production gate

A production transaction must not be submitted until every unchecked item above that applies to the selected deployment has been completed and independently reviewed.
