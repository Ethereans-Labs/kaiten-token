// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IERC20Approve.sol";
import { AllowanceLib, ApproveLib } from "../util/Libraries.sol";

abstract contract ERC20Approve is IERC20Approve {
    using AllowanceLib for address;
    using ApproveLib for address;

    function allowance(address owner, address spender) override public view returns (uint256 value) {
        return owner._allowance(spender);
    }

    function approve(address spender, uint256 amount) override external returns (bool) {
        return msg.sender._approve(spender, amount, true);
    }
}