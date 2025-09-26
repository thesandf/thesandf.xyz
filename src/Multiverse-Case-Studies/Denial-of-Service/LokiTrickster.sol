// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Loki jams the Bifrost by reverting on receive
contract LokiTrickster {
    receive() external payable {
        revert("Loki jams the Bifrost!");
    }
}
