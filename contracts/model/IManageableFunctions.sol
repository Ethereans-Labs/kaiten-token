// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManageableFunctions {

    function functionsManagers(string[] memory methods) external view returns(address[] memory values);

    function functionManager(string memory method) external view returns(address value);

    function functionManagerBySignature(bytes4 signature) external view returns(address value);
}