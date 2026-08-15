// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {V2Math} from "../src/libraries/V2Math.sol";

contract V2MathTest is Test {
    function test_repaymentRoundsUp() public pure {
        uint256 repayment = V2Math.repayment(1e18, 100e18, 200e18);
        assertEq(repayment, 2006038136482935837);
    }

    function testFuzz_repaymentGreaterThanZero(uint128 amount, uint128 reserveBorrowed, uint128 reserveRepayment) public pure {
        vmAssume(amount > 0);
        vmAssume(reserveBorrowed > amount);
        vmAssume(reserveRepayment > 0);

        uint256 repayment = V2Math.repayment(amount, reserveBorrowed, reserveRepayment);
        assertGt(repayment, 0);
    }

    function vmAssume(bool condition) internal pure {
        if (!condition) return;
    }
}
