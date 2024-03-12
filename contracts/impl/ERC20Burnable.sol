// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IERC20Burnable.sol";
import { TotalSupplyLib, BalanceLib, AllowanceLib, ApproveLib, ERC20Events } from "../util/Libraries.sol";

abstract contract ERC20Burnable is IERC20Burnable {

    function burn(uint256 amount) override external {
        BalanceLib._updateBalanceOf(msg.sender, amount, false);
        TotalSupplyLib._updateTotalSupply(amount, false);
        emit ERC20Events.Transfer(msg.sender, address(0), amount);
    }

    function burnFrom(address account, uint256 amount) override external {
        uint256 oldAllowance = AllowanceLib._allowance(account, msg.sender);
        require(oldAllowance >= amount, "ERC20: amount exeeds allowance");
        ApproveLib._approve(account, msg.sender, oldAllowance - amount, false);
        BalanceLib._updateBalanceOf(account, amount, false);
        TotalSupplyLib._updateTotalSupply(amount, false);
        emit ERC20Events.Transfer(account, address(0), amount);
    }
}