// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IERC20Core.sol";
import "./ManageableFunctions.sol";
import { BalanceLib, AllowanceLib, ApproveLib, ERC20Events } from "../util/Libraries.sol";

abstract contract ERC20Core is IERC20Core, ManageableFunctions {

    function transfer(address recipient, uint256 amount) override public virtual delegable returns (bool) {
        if(amount == 0) {
            return true;
        }
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) override public virtual delegable returns (bool) {
        if(amount == 0) {
            return true;
        }
        uint256 oldAllowance = AllowanceLib._allowance(sender, msg.sender);
        require(oldAllowance >= amount, "ERC20: amount exeeds allowance");
        ApproveLib._approve(sender, msg.sender, oldAllowance - amount, false);
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        BalanceLib._updateBalanceOf(from, amount, false);
        BalanceLib._updateBalanceOf(to, amount, true);
        emit ERC20Events.Transfer(from, to, amount);
    }
}