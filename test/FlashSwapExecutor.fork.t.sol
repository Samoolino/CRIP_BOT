// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FlashSwapExecutor} from "../src/FlashSwapExecutor.sol";
import {IV2Pair} from "../src/interfaces/IV2Pair.sol";

/// @notice Real-protocol integration gate. No protocol mocks are used.
/// @dev Configure RPC_URL, V2_FACTORY, V2_ROUTER and V2_PAIR for a selected V2 deployment.
///      With no configuration, the suite exits without running the live-fork assertions.
contract FlashSwapExecutorForkTest is Test {
    function test_realDeploymentInspection() public {
        string memory rpc = vm.envOr("RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;

        address factory = vm.envOr("V2_FACTORY", address(0));
        address router = vm.envOr("V2_ROUTER", address(0));
        address pair = vm.envOr("V2_PAIR", address(0));
        if (factory == address(0) || router == address(0) || pair == address(0)) return;

        uint256 fork = vm.createFork(rpc);
        vm.selectFork(fork);

        assertGt(factory.code.length, 0, "factory has no deployed bytecode");
        assertGt(router.code.length, 0, "router has no deployed bytecode");
        assertGt(pair.code.length, 0, "pair has no deployed bytecode");

        IV2Pair realPair = IV2Pair(pair);
        assertEq(realPair.factory(), factory, "pair factory mismatch");

        address token0 = realPair.token0();
        address token1 = realPair.token1();
        assertTrue(token0 != address(0) && token1 != address(0), "pair token missing");
        assertTrue(token0 != token1, "pair tokens identical");

        (uint112 reserve0, uint112 reserve1,) = realPair.getReserves();
        assertTrue(reserve0 > 0 && reserve1 > 0, "pair has no liquidity");

        FlashSwapExecutor executor = new FlashSwapExecutor(factory, router);
        executor.configurePair(pair);

        assertEq(executor.factory(), factory);
        assertEq(executor.router(), router);
        assertEq(executor.configuredPair(), pair);
    }
}
