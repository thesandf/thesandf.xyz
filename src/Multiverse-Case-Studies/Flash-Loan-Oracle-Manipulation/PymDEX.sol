// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "./MockERC20.sol";

/// @notice Simplified AMM, used as a naive on-chain price oracle (unsafe)
/// @dev Price = reserveB / reserveA. Swaps use:
///      amountBOut = reserveB * amountAIn / (reserveA + amountAIn)
///      Large swaps cause slippage, reducing profit for manipulators.
contract PymDEX {
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    uint256 public reserveA;
    uint256 public reserveB;

    constructor(address _a, address _b, uint256 a, uint256 b) {
        tokenA = MockERC20(_a);
        tokenB = MockERC20(_b);
        reserveA = a;
        reserveB = b;
    }

    /// @notice Get spot price (TokenA→TokenB) as reserveB / reserveA
    /// @dev Unsafe as an oracle: manipulable by large swaps
    function getPymPrice(address, address) external view returns (uint256) {
        if (reserveA == 0) return 0;
        return (reserveB * 1e18) / reserveA;
    }

    /// @notice Swap TokenA for TokenB (no fees, direct reserve update)
    /// @dev AMM math: amountBOut = reserveB * amountAIn / (reserveA + amountAIn)
    function swapExactAForB(uint256 amountAIn, address to) external {
        require(tokenA.transferFrom(msg.sender, address(this), amountAIn), "transferFrom A");
        // AMM output calculation (educational only)
        uint256 amountBOut = (reserveB * amountAIn) / (reserveA + amountAIn);
        reserveA += amountAIn;
        require(reserveB >= amountBOut, "insufficient reserveB");
        reserveB -= amountBOut;
        require(tokenB.transfer(to, amountBOut), "transfer B");
    }

    /// @notice Swap TokenB for TokenA
    /// @dev AMM math: amountAOut = reserveA * amountBIn / (reserveB + amountBIn)
    function swapExactBForA(uint256 amountBIn, address to) external {
        require(tokenB.transferFrom(msg.sender, address(this), amountBIn), "transferFrom B");
        // AMM output calculation (educational only)
        uint256 amountAOut = (reserveA * amountBIn) / (reserveB + amountBIn);
        reserveB += amountBIn;
        require(reserveA >= amountAOut, "insufficient reserveA");
        reserveA -= amountAOut;
        require(tokenA.transfer(to, amountAOut), "transfer A");
    }

    /// @notice Fund DEX with additional reserves (for tests/demo)
    function fund(uint256 a, uint256 b) external {
        reserveA += a;
        reserveB += b;
    }
}
