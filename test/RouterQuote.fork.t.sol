// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IV2Pair} from "../src/interfaces/IV2Pair.sol";
import {IV2Router02} from "../src/interfaces/IV2Router02.sol";
import {V2Math} from "../src/libraries/V2Math.sol";

/// @notice Optional real-router quote and repayment inspection.
/// @dev Uses only real deployed protocol contracts on a fork.
contract RouterQuoteForkTest is Test {
    function test_realRouterQuoteAndRepayment() public {
        string memory rpc = vm.envOr("RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;

        address router = vm.envOr("V2_ROUTER", address(0));
        address pair = vm.envOr("V2_PAIR", address(0));
        address borrowToken = vm.envOr("BORROW_TOKEN", address(0));
        address intermediate = vm.envOr("INTERMEDIATE_TOKEN", address(0));
        uint256 amount = vm.envOr("BORROW_AMOUNT_WEI", uint256(0));
        if (router == address(0) || pair == address(0) || borrowToken == address(0) || intermediate == address(0) || amount == 0) return;

        uint256 fork = vm.createFork(rpc);
        vm.selectFork(fork);

        IV2Pair realPair = IV2Pair(pair);
        address token0 = realPair.token0();
        address token1 = realPair.token1();
        assertTrue(borrowToken == token0 || borrowToken == token1, "borrow token is not a pair asset");

        address repaymentToken = borrowToken == token0 ? token1 : token0;
        assertTrue(intermediate != borrowToken && intermediate != repaymentToken, "intermediate token invalid");

        (uint112 reserve0, uint112 reserve1,) = realPair.getReserves();
        uint256 reserveBorrowed = borrowToken == token0 ? reserve0 : reserve1;
        uint256 reserveRepayment = borrowToken == token0 ? reserve1 : reserve0;
        assertTrue(amount < reserveBorrowed, "borrow exceeds pair reserve");

        uint256 repayment = V2Math.repayment(amount, reserveBorrowed, reserveRepayment);
        assertGt(repayment, amount, "repayment must exceed borrowed amount");

        address[] memory path = new address[](3);
        path[0] = borrowToken;
        path[1] = intermediate;
        path[2] = repaymentToken;

        uint256[] memory amounts = IV2Router02(router).getAmountsOut(amount, path);
        assertEq(amounts.length, path.length, "unexpected quote length");
        assertEq(amounts[0], amount, "router quote input mismatch");
        assertGt(amounts[2], 0, "router returned no output");

        assertGt(amounts[2], repayment, "route quote does not cover flash-swap repayment");
    }
}
