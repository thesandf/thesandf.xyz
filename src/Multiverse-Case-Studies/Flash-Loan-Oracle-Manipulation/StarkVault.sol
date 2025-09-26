// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "./MockERC20.sol";

interface IPymPrice {
    function getPymPrice(address tokenA, address tokenB) external view returns (uint256);
}

/// @notice Vulnerable lending vault using naive PymDEX spot price
/// @dev Reads price from PymDEX every time. Vulnerable to flash-loan manipulation.
contract StarkVault {
    MockERC20 public collateral; // tokenA
    MockERC20 public borrowToken; // tokenB
    IPymPrice public pym;
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public debt;
    uint256 public constant LTV_PERCENT = 50;

    constructor(address _collateral, address _borrow, address _pym) {
        collateral = MockERC20(_collateral);
        borrowToken = MockERC20(_borrow);
        pym = IPymPrice(_pym);
    }

    /// @notice Deposit collateral (TokenA)
    function depositCollateral(uint256 amount) external {
        require(amount > 0, "zero");
        require(collateral.transferFrom(msg.sender, address(this), amount), "transferFrom");
        collateralBalance[msg.sender] += amount;
    }

    /// @notice Borrow TokenB against collateral, using spot price (vulnerable)
    /// @dev Uses PymDEX spot price, which can be manipulated in a flash loan
    function borrow(uint256 amount) external {
        require(amount > 0, "zero");
        uint256 price = pym.getPymPrice(address(collateral), address(borrowToken)); // spot price (vulnerable)
        uint256 collateralValue = (collateralBalance[msg.sender] * price) / 1e18;
        require(collateralValue * LTV_PERCENT / 100 >= debt[msg.sender] + amount, "undercollateralized");
        debt[msg.sender] += amount;
        require(borrowToken.transfer(msg.sender, amount), "transfer borrow");
    }

    /// @notice Liquidate undercollateralized user (using manipulated price)
    /// @dev Attacker can force liquidation by manipulating price in same tx
    function liquidate(address user) external {
        uint256 price = pym.getPymPrice(address(collateral), address(borrowToken));
        uint256 collateralValue = (collateralBalance[user] * price) / 1e18;
        require(collateralValue * LTV_PERCENT / 100 < debt[user], "not liquidatable");
        uint256 seized = collateralBalance[user];
        collateralBalance[user] = 0;
        require(collateral.transfer(msg.sender, seized), "transfer seized");
    }
}
