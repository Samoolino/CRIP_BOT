// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IV2Pair} from "../src/interfaces/IV2Pair.sol";

contract InspectPair is Script {
    function run() external view {
        address pair = vm.envAddress("V2_PAIR");
        address expectedFactory = vm.envAddress("V2_FACTORY");

        address factory = IV2Pair(pair).factory();
        address token0 = IV2Pair(pair).token0();
        address token1 = IV2Pair(pair).token1();
        (uint112 reserve0, uint112 reserve1, uint32 timestamp) = IV2Pair(pair).getReserves();

        console2.log("pair", pair);
        console2.log("factory", factory);
        console2.log("expected factory", expectedFactory);
        console2.log("factory matches", factory == expectedFactory);
        console2.log("token0", token0);
        console2.log("token1", token1);
        console2.log("reserve0", uint256(reserve0));
        console2.log("reserve1", uint256(reserve1));
        console2.log("reserve timestamp", uint256(timestamp));

        require(factory == expectedFactory, "pair factory mismatch");
        require(token0 != address(0) && token1 != address(0) && token0 != token1, "invalid pair tokens");
    }
}
