// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../model/IERC20Permit.sol";
import { ApproveLib } from "../util/Libraries.sol";

abstract contract ERC20Permit is IERC20Permit {
    using ApproveLib for address;

    bytes32 override public immutable DOMAIN_SEPARATOR;

    constructor() {
        (,string memory domainSeparatorName, string memory domainSeparatorVersion) = permitInfo();
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(domainSeparatorName)),
                keccak256(bytes(domainSeparatorVersion)),
                block.chainid,
                address(this)
            )
        );
    }

    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) override external {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");
        (string memory permitSignature,,) = permitInfo();
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(keccak256(bytes(permitSignature)), owner, spender, value, _increaseNonces(owner), deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'INVALID_SIGNATURE');
        owner._approve(spender, value, true);
    }

    function permitInfo() public override pure returns(string memory permitSignature, string memory domainSeparatorName, string memory domainSeparatorVersion) {
        permitSignature = "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)";
        domainSeparatorName = "SoS Token";
        domainSeparatorVersion = "1";
    }

    function nonces(address owner) override external view returns (uint256 value) {
        (value,) = _nonces(owner);
    }

    function _nonces(address owner) private view returns(uint256 value, bytes32 key) {
        key = keccak256(abi.encodePacked("nonces", owner));
        assembly {
            value := sload(key)
        }
    }

    function _increaseNonces(address owner) private returns(uint256 oldValue) {
        (uint256 value, bytes32 key) = _nonces(owner);
        oldValue = value++;
        assembly {
            sstore(key, value)
        }
    }
}