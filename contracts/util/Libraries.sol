// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
library BalanceMathLib {
    function _update(bytes32 key, uint256 amount, bool add) internal returns(uint256 oldValue, uint256 newValue) {

        assembly {
            oldValue := sload(key)
        }

        newValue = oldValue;

        if(amount != 0) {
            if(add) {
                newValue += amount;
            } else {
                require(amount <= newValue, "math");
                newValue -= amount;
            }
            assembly {
                sstore(key, newValue)
            }
        }
    }
}

library TotalSupplyLib {
    bytes32 internal constant _totalSupplyKey = 0x3b199c13f2f664dd6072f28dca68234bfe807e2c585d7f2c2dd6ca130425f7f4;

    function _totalSupply() internal view returns(uint256 value) {
        assembly {
            value := sload(_totalSupplyKey)
        }
    }

    function _updateTotalSupply(uint256 amount, bool add) internal returns(uint256 oldValue, uint256 newValue) {
        return BalanceMathLib._update(_totalSupplyKey, amount, add);
    }
}

library BalanceLib {
    function _balanceKey(address owner) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(bytes32(0x8c711c71c841a0b57e9c348e630100ef0388c980ef7833ea525f8a88be9c528b), owner));
    }

    function _balanceOf(address owner) internal view returns(uint256 value) {
        bytes32 key = _balanceKey(owner);
        assembly {
            value := sload(key)
        }
    }

    function _updateBalanceOf(address owner, uint256 amount, bool add) internal returns(uint256 oldValue, uint256 newValue) {
        return BalanceMathLib._update(_balanceKey(owner), amount, add);
    }
}

library ManageableFunctionsLib {
    address internal constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function _functionManagerKey(string memory method) internal pure returns(bytes32 key, bytes4 signature) {
        key = _functionManagerKey(signature = bytes(method).length == 0 ? signature : bytes4(keccak256(abi.encodePacked(method))));
    }

    function _functionManagerKey(bytes4 signature) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(bytes32(0xd3b8e69b943f0b5cdf78676605268bb628a1252c7ee2b027a749c87ba9c2bf96), signature));
    }

    event FunctionManager(bytes4 indexed signature, address indexed oldValue, address indexed newValue, string method);

    function _setFunctionManager(string memory method, address newValue) internal returns(address oldValue) {
        (bytes32 key, bytes4 signature) = _functionManagerKey(method);
        assembly {
            oldValue := sload(key)
            sstore(key, newValue)
        }
        emit FunctionManager(signature, oldValue, newValue, method);
    }

    function _setFunctionManagers(string[] memory methods, address[] memory values) internal returns(address[] memory oldValues) {
        if(methods.length == 0) {
            return oldValues;
        }
        oldValues = new address[](methods.length);
        address defaultValue = values.length == 0 ? address(0) : values[0];
        for(uint256 i = 0; i < methods.length; i++) {
            oldValues[i] = _setFunctionManager(methods[i], i < values.length ? values[i] : defaultValue);
        }
    }
}

library AllowanceKeyLib {

    function _allowanceKey(address owner, address spender) internal pure returns(bytes32) {
        return keccak256(abi.encodePacked(bytes32(0x4e43e5fe43c3de8144818a4355e4e23384113a1cdc7e4b106dc8f6506b022692), owner, spender));
    }
}

library AllowanceLib {
    using AllowanceKeyLib for address;

    function _allowance(address owner, address spender) internal view returns (uint256 value) {
        bytes32 key = owner._allowanceKey(spender);
        assembly {
            value := sload(key)
        }
    }
}

library ApproveLib {
    using AllowanceKeyLib for address;

    function _approve(address owner, address spender, uint256 value, bool alsoEvent) internal returns (bool) {
        bytes32 key = owner._allowanceKey(spender);
        assembly {
            sstore(key, value)
        }
        if(alsoEvent) {
            emit ERC20Events.Approval(owner, spender, value);
        }
        return true;
    }
}

library ERC20Events {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
}