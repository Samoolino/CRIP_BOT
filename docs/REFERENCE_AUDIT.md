# Reference audit — pedrobergamini/flashloaner-contract

## Scope

This document records an architectural and security review of the reference project before CRIP_BOT implementation. It is an engineering assessment, not a claim of a formal third-party security audit.

## 1. Execution model

The reference is a Uniswap V2-compatible **flash swap** pattern. The pair sends one reserve asset to the borrower before the callback returns. The borrower must then return the required amount of the same asset (or the alternate asset according to V2 settlement rules) before the transaction completes.

This differs from a generic Aave-style flash loan API: liquidity originates from a V2 pair and the callback is initiated by that pair.

## 2. Main control flow

```text
caller
  |
  | start flash swap
  v
V2 Pair
  |
  | transfer borrowed token
  | call borrower callback
  v
FlashLoaner callback
  |
  +--> validate amount / side
  +--> validate caller == expected pair
  +--> perform configured router swap
  +--> compute required repayment
  +--> require proceeds >= repayment
  +--> transfer repayment to pair
  +--> transfer residual profit to initiator
  v
transaction commits atomically
```

## 3. Positive security properties

- Atomicity gives the strategy a hard settlement boundary: an underfunded repayment reverts the whole transaction.
- The callback verifies the pair identity rather than trusting an arbitrary caller.
- The implementation rejects unsupported dual-sided borrow amounts.
- Repayment is computed from V2-style reserve math rather than treated as a fixed arbitrary fee.
- The project includes tests and deployment/simulation tooling, which provides a useful baseline for reproducing expected behavior.

## 4. Findings / risks to address in CRIP_BOT

### F-01 — deployment-specific pair init-code hash
**Severity: High portability risk**

V2 pair address derivation depends on the factory address, token ordering, and the pair init-code hash. A constant copied from one V2 deployment must not be assumed valid on another deployment or fork.

**CRIB_BOT action:** use explicit deployment configuration and verify the derived pair against the configured factory. Do not hard-wire a universal hash.

### F-02 — router trust boundary
**Severity: High**

Any executor that can be directed to an arbitrary router/call target can become a general transaction forwarder. That expands the attack surface substantially.

**CRIB_BOT action:** whitelist routers per deployment and expose only the minimum swap operation required by the strategy.

### F-03 — token/path validation
**Severity: High**

The borrowed asset, output asset, and swap path must be consistent with the expected strategy. A malformed path can cause failed settlement or unexpected asset exposure.

**CRIB_BOT action:** validate path endpoints against the borrowed/output assets and reject malformed paths.

### F-04 — profitability is not the same as gross token surplus
**Severity: Medium/High**

A token-level surplus can still be economically negative after gas, router fees, price impact, and other execution costs.

**CRIB_BOT action:** keep the contract's minimum repayment/surplus invariant strict, while the off-chain bot computes expected net PnL before submission.

### F-05 — approvals and token behavior
**Severity: Medium**

ERC-20 implementations vary. Unlimited approvals and non-standard tokens can create operational/security issues.

**CRIB_BOT action:** use narrowly scoped approvals where practical, maintain a token allowlist, and test fee-on-transfer/non-standard-token behavior explicitly. The first production strategy should avoid unsupported token classes.

### F-06 — callback reentrancy / nested execution
**Severity: Medium**

External token/router calls occur during the callback. Re-entry can create unexpected state transitions if the executor stores mutable execution state.

**CRIB_BOT action:** keep execution state minimal, validate the active pair/initiator, and use a non-reentrant execution guard where stateful logic requires it.

### F-07 — profit recipient authorization
**Severity: Medium**

Profit should not be transferable to an attacker-controlled address through callback calldata.

**CRIB_BOT action:** bind the profit recipient to the authorized initiator or a configured treasury and validate it before execution.

### F-08 — stale quotes / MEV
**Severity: High operational risk**

An off-chain quote can become invalid between discovery and inclusion. Public mempools also expose profitable transactions to frontrunning/sandwiching or competing searchers.

**CRIB_BOT action:** simulate immediately before submission, impose a deadline/block bound and minimum profit, and support private transaction routing where appropriate.

## 5. Recommended CRIP_BOT architecture

### On-chain

`FlashSwapExecutor` should be deliberately small. Responsibilities:

- receive the V2 callback;
- authenticate the originating pair;
- authenticate the authorized initiator;
- validate token/path/router configuration;
- execute the exact approved swap operation;
- calculate/verify settlement amount;
- repay the source pair;
- transfer residual surplus to the configured treasury/initiator;
- emit structured execution events.

### Off-chain

The bot should own:

- market discovery;
- multi-venue quote comparison;
- reserve/state reads;
- gas estimation;
- expected net PnL calculation;
- slippage/deadline policy;
- transaction simulation;
- nonce management;
- submission and monitoring.

## 6. Audit methodology for our implementation

Before deployment, review:

- authorization and callback authentication;
- pair derivation and factory verification;
- arithmetic/rounding;
- ERC-20 transfer/approval assumptions;
- external-call ordering;
- reentrancy;
- token/path/router allowlists;
- profit accounting;
- emergency pause/withdrawal policy;
- deployment configuration;
- fork and invariant tests;
- static-analysis findings.

## 7. Clone policy

CRIP_BOT should **not** copy the reference repository wholesale. We reproduce the public objective and underlying protocol mechanism while writing an independently structured implementation. Reference code may be studied for compatibility and behavior, but CRIP_BOT will have its own interfaces, configuration model, tests, documentation, and security controls.
