// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

interface IQuoteRouter {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IQuotePair {
    function token0() external view returns (address);
    function token1() external view returns (address);
}

/// @notice Optional real-router quote inspection. No protocol mocks are used.
/// @dev Requires RPC_URL, V2_ROUTER, V2_PAIR, BORROW_TOKEN,
///      INTERMEDIATE_TOKEN and BORROW_AMOUNT_WEI when the gate is enabled.
contract RouterQuoteForkTest is Test {
    function test_realRouterQuote() public {
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

        address token0 = IQuotePair(pair).token0();
        address token1 = IQuotePair(pair).token1();
        assertTrue(borrowToken == token0 || borrowToken == token1, "borrow token is not a pair asset");
        address repaymentToken = borrowToken == token0 ? token1 : token0;
        assertTrue(intermediate != borrowToken && intermediate != repaymentToken, "intermediate token invalid");

        address[] memory path = new address[](3);
        path[0] = borrowToken;
        path[1] = intermediate;
        path[2] = repaymentToken;

        uint256[] memory amounts = IQuoteRouter(router).getAmountsOut(amount, path);
        assertEq(amounts.length, 3, "unexpected quote length");
        assertEq(amounts[0], amount, "router quote input mismatch");
        assertGt(amounts[2], 0, "router returned no output");
    }
}
