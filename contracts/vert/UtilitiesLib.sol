// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UtilitiesLib {
    uint256 internal constant AMOUNT_PERCENTAGE = 2e17;
    uint256 internal constant TREASURY_PERCENTAGE = 5e16;
    uint256 internal constant MARKETING_PERCENTAGE = 12e16;
    uint256 internal constant BOOTSTRAP_PERCENTAGE = 13e16;
    uint256 internal constant REVENUE_SHARE_PERCENTAGE = 1e17;
    uint256 internal constant ANTI_WHALE_MAX_BALANCE = 1500000e18;
    uint256 internal constant ANTI_WHALE_MAX_TRANSFER = 750000e18;
}