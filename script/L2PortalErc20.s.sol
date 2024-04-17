// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/L2PortalHypErc20.sol";

contract HyprErc20Script is Script {
    function run() public {
        uint8 decimals = 18;
        address mailbox = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
        uint256 startMintId = 1000001;
        uint256 endMintId = 1500000;
        uint256 mintFee = 0 ether;
        uint256 bridgeFee = 0 ether;
        address feeCollector = 0x1c77D3EfbFe8199ac30C15A2cFF3e5d5b1251771;
        uint256 referralEarningBips = 2000;

        vm.broadcast();

        NogemHyperErc20 erc20 = new NogemHyperErc20(
            decimals,
            mailbox,
            startMintId,
            endMintId,
            mintFee,
            bridgeFee,
            feeCollector,
            referralEarningBips
        );
    }
}
