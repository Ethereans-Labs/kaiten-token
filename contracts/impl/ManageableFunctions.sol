// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IManageableFunctions.sol";
import { ManageableFunctionsLib } from "../util/Libraries.sol";

abstract contract ManageableFunctions is IManageableFunctions {
    using ManageableFunctionsLib for string;
    using ManageableFunctionsLib for bytes4;
    using ManageableFunctionsLib for string[];

    event FunctionManager(bytes4 indexed signature, address indexed oldValue, address indexed newValue, string method);

    address internal immutable _this = address(this);

    constructor(string[] memory methods, address[] memory values) {
        methods._setFunctionManagers(values);
    }

    function _tryInitialize() internal {
        string memory method = "initialize()";
        address delegate = functionManager(method);
        if(delegate != address(0) && delegate != _this && delegate != ManageableFunctionsLib.DEAD_ADDRESS) {
            (bool result, bytes memory response) = delegate.delegatecall(abi.encodeWithSignature(method));
            if(!result) {
                assembly {
                    revert(add(0x20, response), mload(response))
                }
            }
            method._setFunctionManager(address(0));
        }
    }

    function functionsManagers(string[] memory methods) override public view returns(address[] memory values) {
        values = new address[](methods.length);
        for(uint256 i = 0; i < methods.length; i++) {
            values[i] = functionManager(methods[i]);
        }
    }

    function functionManager(string memory method) override public view returns(address value) {
        (bytes32 key, ) = method._functionManagerKey();
        assembly {
            value := sload(key)
        }
    }

    function functionManagerBySignature(bytes4 signature) override public view returns(address value) {
        bytes32 key = signature._functionManagerKey();
        assembly {
            value := sload(key)
        }
    }

    receive() virtual external payable {
        _delegateCall(functionManagerBySignature(bytes4(0)));
    }

    fallback() external payable {
        _delegateCall(functionManagerBySignature(msg.sig));
    }

    modifier delegable() {
        address delegate = functionManagerBySignature(msg.sig);
        if(delegate == address(0) || delegate == _this) {
            _;
        } else {
            _delegateCall(delegate);
        }
    }

    function _delegateCall(address delegate) private {
        require(delegate != address(0) && delegate != _this && delegate != ManageableFunctionsLib.DEAD_ADDRESS);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), delegate, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch success
                case 0 {revert(0, returndatasize())}
                default { return(0, returndatasize())}
        }
    }

    function _tryStaticCall() internal view returns(bool) {
        address delegate = functionManagerBySignature(msg.sig);
        if(delegate == address(0) || delegate == _this) {
            return false;
        }
        require(delegate != ManageableFunctionsLib.DEAD_ADDRESS);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := staticcall(gas(), delegate, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch success
                case 0 {revert(0, returndatasize())}
                default { return(0, returndatasize())}
        }
    }
}