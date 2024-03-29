// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Approve {

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}