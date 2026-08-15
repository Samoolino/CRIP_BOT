// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

contract RealV2ForkPreflightTest is Test {
    function test_requiredConfigurationShape() public {
        string memory rpc = vm.envOr("RPC_URL", string(""));
        address factory = vm.envOr("V2_FACTORY", address(0));
        address router = vm.envOr("V2_ROUTER", address(0));
        address pair = vm.envOr("V2_PAIR", address(0));

        if (bytes(rpc).length == 0 && factory == address(0) && router == address(0) && pair == address(0)) {
            return;
        }

        assertGt(bytes(rpc).length, 0, "RPC_URL missing");
        assertTrue(factory != address(0), "V2_FACTORY missing");
        assertTrue(router != address(0), "V2_ROUTER missing");
        assertTrue(pair != address(0), "V2_PAIR missing");
    }
}
