// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from 'forge-std/Script.sol';
import {FlashSwapExecutor} from '../src/FlashSwapExecutor.sol';

contract DeployExecutor is Script {
    function run() external returns (FlashSwapExecutor executor) {
        address factory = vm.envAddress('V2_FACTORY');
        address router = vm.envAddress('V2_ROUTER');

        vm.startBroadcast();
        executor = new FlashSwapExecutor(factory, router);
        vm.stopBroadcast();

        console2.log('FlashSwapExecutor', address(executor));
        console2.log('Factory', factory);
        console2.log('Router', router);
    }
}
