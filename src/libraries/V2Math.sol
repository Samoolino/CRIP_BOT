// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Pure Uniswap-V2-style flash-swap repayment math.
library V2Math {
    error BorrowExceedsReserve();

    function repayment(uint256 amountOut, uint256 reserveBorrowed, uint256 reserveRepayment)
        internal
        pure
        returns (uint256)
    {
        if (amountOut >= reserveBorrowed) revert BorrowExceedsReserve();
        uint256 numerator = amountOut * reserveRepayment * 1000;
        uint256 denominator = (reserveBorrowed - amountOut) * 997;
        return numerator / denominator + 1;
    }
}
