// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20Approve.sol";
import "./IERC20Burnable.sol";
import "./IERC20Core.sol";
import "./IERC20Metadata.sol";
import "./IERC20Mintable.sol";
import "./IERC20Permit.sol";
import "./IERC20ReadableData.sol";

interface IERC20 is IERC20Approve, IERC20Burnable, IERC20Core, IERC20Metadata, IERC20Mintable, IERC20Permit, IERC20ReadableData {}