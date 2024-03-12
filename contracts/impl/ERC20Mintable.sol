// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IERC20Mintable.sol";
import "./Ownable.sol";
import "./ManageableFunctions.sol";
import { TotalSupplyLib, BalanceLib, AllowanceLib, ApproveLib, ERC20Events } from "../util/Libraries.sol";

abstract contract ERC20Mintable is IERC20Mintable, Ownable, ManageableFunctions {
    function mint(address account, uint256 amount) override external onlyOwner delegable returns (bool) {
        _mint(account, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        BalanceLib._updateBalanceOf(account, amount, true);
        TotalSupplyLib._updateTotalSupply(amount, true);
        emit ERC20Events.Transfer(address(0), account, amount);
    }
}