# CI Status

## Known baseline failure

GitHub Actions run `31863972969` reached the Foundry toolchain successfully but failed at `forge fmt --check`. Build and test steps were therefore skipped.

The branch contains a formatting cleanup for the repayment-math test. A new GitHub Actions run should be treated as the authoritative validation of the current branch.

## Release rule

Do not merge the security branch until the workflow reports success for:

1. format check;
2. build;
3. tests.

After CI succeeds, the next gate is a real-protocol fork test against a selected V2 deployment. No production transaction should be broadcast merely because CI passes.
