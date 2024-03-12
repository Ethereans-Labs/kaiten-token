// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IReadableStorage.sol";

abstract contract ReadableStorage is IReadableStorage {

    function readStorage(bytes32 key) override public view returns(bytes32 value) {
        assembly {
            value := sload(key)
        }
    }

    function readStorage(bytes32[] calldata keys) override external view returns(bytes32[] memory values) {
        values = new bytes32[](keys.length);
        for(uint256 i = 0; i < keys.length; i++) {
            values[i] = readStorage(keys[i]);
        }
    }
}