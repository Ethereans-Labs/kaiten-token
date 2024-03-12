// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract OwnableView {

    bytes32 internal constant OWNER_KEY = 0xdc6edb7e21c7d6802c30a4249460696aa4c6ef3b5aee9c59996f8fedc7fbaefe;

    modifier onlyOwner() {
        require(msg.sender == _owner(), "Unauthorized");
        _;
    }

    function _owner() internal view returns (address value) {
        assembly {
            value := sload(OWNER_KEY)
        }
    }
}