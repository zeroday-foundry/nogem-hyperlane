// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/L2PortalHypNFT721.sol";

/**
* @author L2Portal
* @title L2PortalHypNFT721Script
* @notice Deploy script for {L2PortalHypNFT721}
*/
contract L2PortalHypNFT721Script is Script {

    function run() public {     
        //POLYGON
        address mailbox = 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766;
        uint256 startMintId = 1000001;
        uint256 endMintId = 1500000;
        uint256 mintFee = 0 ether;
        uint256 bridgeFee = 0 ether;
        address feeCollector = 0x1c77D3EfbFe8199ac30C15A2cFF3e5d5b1251771;
        uint256 referralEarningBips = 2000;


        vm.broadcast();

        NogemHyper L2portal = new NogemHyper(
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
