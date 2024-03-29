//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMulticall {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
