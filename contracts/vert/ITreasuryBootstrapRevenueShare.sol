// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IVestingContract.sol";

interface ITreasuryBootstrapRevenueShare {
    function completeInitialization(address treasuryAddress) external returns(address operatorAddress);
    function setTreasuryAddress(address newValue) external returns(address oldValue);
    function updatePositionOf(address account, uint256 amount, uint256 vestedAmount) external payable;
    function finalizePosition(uint256 treasuryBalance, uint256 additionalLiquidity, uint256 vestingEnds) external payable;
}