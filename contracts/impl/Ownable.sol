// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IOwnable.sol";
import "./OwnableView.sol";

abstract contract Ownable is IOwnable, OwnableView {

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    function owner() override external view returns (address) {
        return _owner();
    }

    function renounceOwnership() override external onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) override external onlyOwner {
        require(newOwner != address(0), "Invalid");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) private {
        address oldOwner = _owner();
        assembly {
            sstore(OWNER_KEY, newOwner)
        }
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}