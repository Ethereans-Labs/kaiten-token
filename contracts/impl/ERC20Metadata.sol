// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IERC20Metadata.sol";
import "./ManageableFunctions.sol";

abstract contract ERC20Metadata is IERC20Metadata, ManageableFunctions {

    bytes32 private immutable _name;
    bytes32 private immutable _symbol;
    uint8 override public immutable decimals;

    constructor(string memory __name, string memory __symbol, uint8 __decimals) {
        _name = bytes32(abi.encodePacked(__name));
        _symbol = bytes32(abi.encodePacked(__symbol));
        decimals = __decimals;
    }

    function name() override external view returns (string memory value) {
        if(!_tryStaticCall()) {
            return _asString(_name);
        }
    }

    function symbol() override external view returns (string memory value) {
        if(!_tryStaticCall()) {
            return _asString(_symbol);
        }
    }

    function _asString(bytes32 value) private pure returns (string memory) {
        uint8 i = 0;
        while(i < 32 && value[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && value[i] != 0; i++) {
            bytesArray[i] = value[i];
        }
        return string(bytesArray);
    }
}