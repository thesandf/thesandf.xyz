// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
   The BifrostBridge pays Asgardians their Ether by looping through all citizens.
   Loki can jam the bridge by reverting in his fallback, blocking ALL payouts.
*/

contract BifrostBridgeVulnerable {
    address[] public asgardians;
    mapping(address => uint256) public vaultOfAsgard;

    /// @notice Asgardians send their Ether to the Bifrost
    function enterBifrost(address realmWalker) external payable {
        require(msg.value > 0, "Bifrost requires Ether toll");
        if (vaultOfAsgard[realmWalker] == 0) {
            asgardians.push(realmWalker);
        }
        vaultOfAsgard[realmWalker] += msg.value;
    }

    /// @notice Heimdall distributes Ether to all Asgardians (⚠️ Vulnerable)
    function openBifrost() external {
        for (uint256 i = 0; i < asgardians.length; i++) {
            address traveler = asgardians[i];
            uint256 tribute = vaultOfAsgard[traveler];
            if (tribute > 0) {
                //  Loki can revert here and jam the bridge
                (bool sent,) = payable(traveler).call{value: tribute}("");
                require(sent, "Bifrost jammed!");
                vaultOfAsgard[traveler] = 0;
            }
        }
    }
}
