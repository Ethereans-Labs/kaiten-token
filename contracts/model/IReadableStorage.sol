// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReadableStorage {

    function readStorage(bytes32 key) external view returns(bytes32 value);

    function readStorage(bytes32[] calldata keys) external view returns(bytes32[] memory values);
}