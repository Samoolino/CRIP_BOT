// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IV2Pair} from "../src/interfaces/IV2Pair.sol";
import {V2Math} from "../src/libraries/V2Math.sol";

contract QuoteRepayment is Script {
    function run() external view {
        address pair = vm.envAddress("V2_PAIR");
        uint256 amount = vm.envUint("BORROW_AMOUNT_WEI");

        (uint112 reserve0, uint112 reserve1,) = IV2Pair(pair).getReserves();
        address token0 = IV2Pair(pair).token0();
        address token1 = IV2Pair(pair).token1();

        uint256 repay0 = V2Math.repayment(amount, reserve0, reserve1);
        uint256 repay1 = V2Math.repayment(amount, reserve1, reserve0);

        console2.log("pair", pair);
        console2.log("token0", token0);
        console2.log("token1", token1);
        console2.log("reserve0", uint256(reserve0));
        console2.log("reserve1", uint256(reserve1));
        console2.log("if borrowing token0, repay token1", repay0);
        console2.log("if borrowing token1, repay token0", repay1);
    }
}
