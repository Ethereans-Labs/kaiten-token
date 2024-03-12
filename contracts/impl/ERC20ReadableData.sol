// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IERC20ReadableData.sol";
import { TotalSupplyLib, BalanceLib } from "../util/Libraries.sol";

abstract contract ERC20ReadableData is IERC20ReadableData {

    function totalSupply() override public view returns (uint256) {
        return TotalSupplyLib._totalSupply();
    }

    function balanceOf(address account) override public view returns (uint256) {
        return BalanceLib._balanceOf(account);
    }
}