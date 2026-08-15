// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IV2Factory} from "../src/interfaces/IV2Factory.sol";
import {IV2Pair} from "../src/interfaces/IV2Pair.sol";

/// @notice Discovers and validates an existing V2 pair from a real factory.
/// @dev Read-only operation: this script never broadcasts a transaction.
contract DiscoverPair is Script {
    function run(
        address factory,
        address tokenA,
        address tokenB
    ) external view {
        require(factory != address(0), "factory is zero");
        require(tokenA != address(0) && tokenB != address(0), "token is zero");
        require(tokenA != tokenB, "tokens identical");

        address pair = IV2Factory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "pair does not exist");

        IV2Pair p = IV2Pair(pair);
        require(p.factory() == factory, "pair factory mismatch");
        address token0 = p.token0();
        address token1 = p.token1();
        require(
            (token0 == tokenA || token0 == tokenB) && (token1 == tokenA || token1 == tokenB), "pair tokens mismatch"
        );
        (uint112 reserve0, uint112 reserve1,) = p.getReserves();
        require(reserve0 > 0 && reserve1 > 0, "pair has no liquidity");

        console2.log("Factory:", factory);
        console2.log("Token A:", tokenA);
        console2.log("Token B:", tokenB);
        console2.log("Pair:", pair);
        console2.log("Token0:", token0);
        console2.log("Token1:", token1);
        console2.log("Reserve0:", uint256(reserve0));
        console2.log("Reserve1:", uint256(reserve1));
    }
}
