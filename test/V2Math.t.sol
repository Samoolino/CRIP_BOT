// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {V2Math} from "../src/libraries/V2Math.sol";

contract V2MathTest is Test {
    function test_repaymentRoundsUp() public pure {
        uint256 repayment = V2Math.repayment(1e18, 100e18, 200e18);
        assertEq(repayment, 2026280862790391377);
    }

    function testFuzz_repaymentPositive(
        uint112 amount,
        uint112 reserveBorrowed,
        uint112 reserveRepayment
    ) public pure {
        if (amount == 0 || reserveBorrowed <= amount || reserveRepayment == 0) return;
        uint256 repayment = V2Math.repayment(amount, reserveBorrowed, reserveRepayment);
        assertGt(repayment, 0);
    }
}
