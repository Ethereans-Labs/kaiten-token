// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../impl/ERC20Approve.sol";
import "../impl/ERC20Burnable.sol";
import "../impl/ERC20Core.sol";
import "../impl/ERC20Metadata.sol";
import "../impl/ERC20Mintable.sol";
import "../impl/ERC20Permit.sol";
import "../impl/ERC20ReadableData.sol";

contract Token is ERC20Approve, ERC20Burnable, ERC20Core, ERC20Metadata, ERC20Mintable, ERC20Permit, ERC20ReadableData {

    constructor(address initialOwner, string[] memory methods, address[] memory values) Ownable(initialOwner) ManageableFunctions(methods, values) ERC20Metadata("Codename: Kaiten", "KAI", 18) {
    }
}