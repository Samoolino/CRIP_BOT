// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {FlashSwapExecutor} from "../src/FlashSwapExecutor.sol";

/// @notice Broadcast-free fork simulation entry point.
/// @dev The transaction is intentionally not broadcast by this script. Use a fork RPC
///      and run the desired executor call through `cast send --trace` or a dedicated
///      integration harness after reviewing the quoted opportunity.
contract SimulateFork is Script {
    function run() external view {
        address executor = vm.envAddress("EXECUTOR_ADDRESS");
        address pair = vm.envAddress("V2_PAIR");
        address factory = vm.envAddress("V2_FACTORY");
        address router = vm.envAddress("V2_ROUTER");

        console2.log("executor", executor);
        console2.log("pair", pair);
        console2.log("factory", factory);
        console2.log("router", router);
        console2.log("configured pair", FlashSwapExecutor(executor).configuredPair());
        console2.log("executor owner", FlashSwapExecutor(executor).owner());
        require(FlashSwapExecutor(executor).configuredPair() == pair, "executor pair mismatch");
        require(FlashSwapExecutor(executor).factory() == factory, "executor factory mismatch");
        require(FlashSwapExecutor(executor).router() == router, "executor router mismatch");
    }
}
