// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FlashSwapExecutor} from "../src/FlashSwapExecutor.sol";
import {IV2Pair} from "../src/interfaces/IV2Pair.sol";

interface IExecutionRouter {
    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

interface IERC20Like {
    function balanceOf(
        address account
    ) external view returns (uint256);
}

/// @notice Opt-in real-protocol atomic execution gate. No mocks are used.
/// @dev Runs only when the fork configuration is complete. It never broadcasts a transaction.
contract FlashSwapExecutorExecutionForkTest is Test {
    function test_realAtomicExecutionOnFork() public {
        string memory rpc = vm.envOr("RPC_URL", string(""));
        if (bytes(rpc).length == 0) return;

        address factory = vm.envOr("V2_FACTORY", address(0));
        address router = vm.envOr("V2_ROUTER", address(0));
        address pair = vm.envOr("V2_PAIR", address(0));
        address borrowToken = vm.envOr("BORROW_TOKEN", address(0));
        address repaymentConfigured = vm.envOr("REPAYMENT_TOKEN", address(0));
        address intermediate = vm.envOr("INTERMEDIATE_TOKEN", address(0));
        uint256 amount = vm.envOr("BORROW_AMOUNT_WEI", uint256(0));
        uint256 minProfit = vm.envOr("MIN_PROFIT_WEI", uint256(0));

        if (
            factory == address(0) || router == address(0) || pair == address(0) || borrowToken == address(0)
                || intermediate == address(0) || amount == 0
        ) return;

        uint256 fork = vm.createFork(rpc);
        vm.selectFork(fork);

        assertGt(factory.code.length, 0, "factory has no bytecode");
        assertGt(router.code.length, 0, "router has no bytecode");
        assertGt(pair.code.length, 0, "pair has no bytecode");

        IV2Pair realPair = IV2Pair(pair);
        assertEq(realPair.factory(), factory, "pair factory mismatch");
        address token0 = realPair.token0();
        address token1 = realPair.token1();
        assertTrue(borrowToken == token0 || borrowToken == token1, "borrow token is not pair asset");

        address repaymentToken = borrowToken == token0 ? token1 : token0;
        if (repaymentConfigured != address(0)) {
            assertEq(repaymentConfigured, repaymentToken, "configured repayment token mismatch");
        }
        assertTrue(intermediate != borrowToken && intermediate != repaymentToken, "invalid intermediate token");

        (uint112 reserve0, uint112 reserve1,) = realPair.getReserves();
        uint256 reserveBorrowed = borrowToken == token0 ? reserve0 : reserve1;
        uint256 reserveRepayment = borrowToken == token0 ? reserve1 : reserve0;
        assertGt(reserveBorrowed, amount, "borrow exceeds reserve");
        assertGt(reserveRepayment, 0, "repayment reserve empty");

        address[] memory path = new address[](3);
        path[0] = borrowToken;
        path[1] = intermediate;
        path[2] = repaymentToken;

        uint256[] memory quote = IExecutionRouter(router).getAmountsOut(amount, path);
        assertEq(quote.length, 3, "unexpected route quote length");
        assertEq(quote[0], amount, "quote input mismatch");

        uint256 repayment = (amount * reserveRepayment * 1000) / ((reserveBorrowed - amount) * 997) + 1;
        assertGt(quote[2], repayment + minProfit, "forked route is not profitable at configured floor");

        uint256 slippageBps = vm.envOr("SLIPPAGE_BPS", uint256(50));
        require(slippageBps < 10_000, "invalid slippage bps");
        uint256 amountOutMin = (quote[2] * (10_000 - slippageBps)) / 10_000;
        uint256 deadline = block.timestamp + vm.envOr("DEADLINE_SECONDS", uint256(60));

        FlashSwapExecutor executor = new FlashSwapExecutor(factory, router);
        executor.configurePair(pair);

        uint256 beforeBalance = IERC20Like(repaymentToken).balanceOf(address(this));
        executor.execute(borrowToken, amount, path, minProfit, amountOutMin, deadline);
        uint256 afterBalance = IERC20Like(repaymentToken).balanceOf(address(this));

        assertGe(afterBalance, beforeBalance + minProfit, "owner did not receive configured minimum profit");
    }
}
