// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../impl/ERC20Core.sol";
import "../impl/ERC20Mintable.sol";
import "../impl/OwnableView.sol";
import "./ITreasuryBootstrapRevenueShare.sol";
import "./UtilitiesLib.sol";
import "./IVestingContract.sol";

contract TreasuryBootstrap is OwnableView, ERC20Core, ERC20Mintable {
    using ManageableFunctionsLib for string[];

    uint256 private constant ONE_HUNDRED = 1e18;

    struct StorageContainer {
        bool loaded;
        Storage content;
    }

    struct Storage {
        uint256 bootstrapStarts;
        address marketingAddress;
        address bootstrapAddress;
        address treasuryAddress;
        uint256 actualPriceWindow;
        uint256[] availableTokensPerWindow;
        uint256[] pricesPerWindow;
        address treasuryBootstrapRevenueShareAddress;
        uint256 treasuryBootstrapFirstRevenueShareAmount;
        uint256 treasuryBalance;
        uint256 treasuryBootstrapAdditionalLiquidity;
        address treasuryBootstrapRevenueShareOperator;
        uint256 bootstrapEnds;
        uint256 antiWhaleSystemEnds;
        uint256 mintReleaseStarts;
        uint256 collectedETH;
        uint256 purchasedSupply;
    }

    constructor(Storage memory __storage) Ownable(address(0)) ManageableFunctions(new string[](0), new address[](0)) {
        StorageContainer storage container = _container();
        container.loaded = true;
        container.content = __storage;
    }

    function _storage() external returns(Storage memory) {
        return _container().content;
    }

    receive() override external payable {
        require(msg.value > 0);
        Storage storage $ = _container().content;
        require(block.timestamp > $.bootstrapStarts && $.treasuryAddress != address(0));
        if(tryFinalizeBootstrapAndEnableAntiWhaleSystem()) {
            msg.sender.call{value : msg.value}("");
            return;
        }

        (uint256[] memory liquidity, uint256 ethToGiveBack) = _calculateLiquidityAndUpdateBootstrapStatus();

        if(ethToGiveBack > 0) {
            msg.sender.call{value : ethToGiveBack}("");
        }

        uint256 total = msg.value - ethToGiveBack;

        $.collectedETH += total;

        uint256 remainingValue = total;

        uint256 amount = _calculatePercentage(total, UtilitiesLib.TREASURY_PERCENTAGE);
        require(amount > 0);
        $.treasuryAddress.call{value : amount}("");
        remainingValue -= amount;

        amount = _calculatePercentage(total, UtilitiesLib.MARKETING_PERCENTAGE);
        require(amount > 0);
        $.marketingAddress.call{value : amount}("");
        remainingValue -= amount;

        amount = _calculatePercentage(total, UtilitiesLib.BOOTSTRAP_PERCENTAGE);
        require(amount > 0);
        $.bootstrapAddress.call{value : amount}("");
        remainingValue -= amount;

        amount = _calculatePercentage(total, UtilitiesLib.REVENUE_SHARE_PERCENTAGE);
        require(amount > 0);
        $.treasuryBootstrapFirstRevenueShareAmount += amount;
        remainingValue -= amount;

        _updatePosition(liquidity, remainingValue);
        tryFinalizeBootstrapAndEnableAntiWhaleSystem();
    }

    function _calculateLiquidityAndUpdateBootstrapStatus() private returns(uint256[] memory liquidity, uint256 ethToGiveBack) {
        Storage storage $ = _container().content;
        liquidity = new uint256[]($.pricesPerWindow.length);
        ethToGiveBack = msg.value;

        while(true) {
            uint256 actualPriceWindow = $.actualPriceWindow;
            if(actualPriceWindow == liquidity.length || ethToGiveBack == 0  || ethToGiveBack < $.pricesPerWindow[actualPriceWindow]) {
                require(ethToGiveBack != msg.value);
                break;
            }
            uint256 pricePerWindow = $.pricesPerWindow[actualPriceWindow];
            uint256 tokens = (ethToGiveBack / pricePerWindow) * 1e18;
            if(tokens == 0) {
                break;
            }
            if(tokens > $.availableTokensPerWindow[actualPriceWindow]) {
                tokens = $.availableTokensPerWindow[actualPriceWindow];
                $.actualPriceWindow++;
            }
            liquidity[actualPriceWindow] = tokens;
            $.availableTokensPerWindow[actualPriceWindow] -= tokens;
            ethToGiveBack -= (pricePerWindow * (tokens / 1e18));
        }
    }

    function _updatePosition(uint256[] memory boughtLiquidity, uint256 value) private {
        Storage storage $ = _container().content;
        uint256 amount;
        uint256 walletAmount;
        for(uint256 i = 0; i < boughtLiquidity.length; i++) {
            if(boughtLiquidity[i] == 0) {
                continue;
            }
            uint256 _walletAmount = _calculatePercentage(boughtLiquidity[i], UtilitiesLib.AMOUNT_PERCENTAGE);
            require(_walletAmount > 0 && boughtLiquidity[i] > _walletAmount);
            amount += (boughtLiquidity[i] - _walletAmount);
            walletAmount += _walletAmount;
        }
        $.purchasedSupply += (amount + walletAmount);
        address treasuryBootstrapRevenueShareAddress = $.treasuryBootstrapRevenueShareAddress;
        super._transfer(address(this), treasuryBootstrapRevenueShareAddress, amount + walletAmount);
        ITreasuryBootstrapRevenueShare(treasuryBootstrapRevenueShareAddress).updatePositionOf{value : value}(msg.sender, amount, walletAmount);
    }

    function tryFinalizeBootstrapAndEnableAntiWhaleSystem() public returns(bool disable) {
        Storage storage $ = _container().content;
        disable = $.treasuryBalance != 0 && functionManagerBySignature(bytes4(0)) != address(0) && (block.timestamp > $.bootstrapEnds || $.actualPriceWindow == $.pricesPerWindow.length);
        if(disable) {
            _finalizePosition();
            _disableBootstrapAndEnableAntiWhaleSystem();
        }
    }

    function _finalizePosition() private {
        Storage storage $ = _container().content;
        uint256 amount = $.treasuryBalance;
        if(amount == 0) {
            return;
        }
        $.treasuryBalance = 0;
        uint256[] memory amounts = $.availableTokensPerWindow;
        for(uint256 i = 0; i < amounts.length; i++) {
            amount += amounts[i];
        }
        address treasuryBootstrapRevenueShareAddress = $.treasuryBootstrapRevenueShareAddress;
        super._transfer(address(this), treasuryBootstrapRevenueShareAddress, amount + $.treasuryBootstrapAdditionalLiquidity);
        ITreasuryBootstrapRevenueShare(treasuryBootstrapRevenueShareAddress).finalizePosition{value : $.treasuryBootstrapFirstRevenueShareAmount}(amount, $.treasuryBootstrapAdditionalLiquidity, ($.antiWhaleSystemEnds += block.timestamp));
    }

    function _disableBootstrapAndEnableAntiWhaleSystem() private {
        string[] memory methods = new string[](4);
        address[] memory values = new address[](methods.length);

        methods[1] = "tryFinalizeBootstrapAndEnableAntiWhaleSystem()";

        methods[2] = "tryDisableAntiWhaleSystem()";
        values[2] = _this;
        methods[3] = "disableAntiWhaleSystem()";
        values[3] = _this;

        methods._setFunctionManagers(values);
    }

    function increaseMintOwnershipReleaseTime(uint256 _seconds) external onlyOwner {
        _container().content.mintReleaseStarts += _seconds;
    }

    function completeInitialization(address treasuryAddress, address[] calldata receivers, uint256[] calldata amounts) external onlyOwner {
        Storage storage $ = _container().content;
        $.treasuryAddress = treasuryAddress;
        $.treasuryBootstrapRevenueShareOperator = ITreasuryBootstrapRevenueShare($.treasuryBootstrapRevenueShareAddress).completeInitialization(treasuryAddress);
        super._mint(address(this), 100000000e18);
        for(uint256 i = 0; i < receivers.length; i++) {
            address receiver = receivers[i];
            uint256 amount = amounts[i];
            super._transfer(address(this), receiver, amount);
            uint256 codeLength;
            assembly {
                codeLength := extcodesize(receiver)
            }
            if(codeLength > 0) {
                receiver.call(abi.encodeWithSelector(IVestingContract(receiver).completeInitialization.selector));
            }
        }
        ManageableFunctionsLib._setFunctionManager("completeInitialization(address,address[],uint256[])", address(0));
    }

    function setFinalNameAndSymbol(address location) external onlyOwner {
        string[] memory methods = new string[](3);
        address[] memory values = new address[](methods.length);

        methods[0] = "name()";
        methods[1] = "symbol()";
        methods[2] = "setFinalNameAndSymbol(address)";

        values[0] = location;
        values[1] = location;

        methods._setFunctionManagers(values);
    }

    function tryDisableAntiWhaleSystem() external {
        require(block.timestamp > _container().content.antiWhaleSystemEnds);
        _disableAntiWhaleSystem();
    }

    function disableAntiWhaleSystem() external onlyOwner {
        _disableAntiWhaleSystem();
    }

    function _disableAntiWhaleSystem() private {
        string[] memory methods = new string[](5);
        address[] memory values = new address[](methods.length);

        methods[0] = "transfer(address,uint256)";
        methods[1] = "transferFrom(address,address,uint256)";

        methods[2] = "tryDisableAntiWhaleSystem()";
        methods[3] = "disableAntiWhaleSystem()";

        methods[4] = "increaseMintOwnershipReleaseTime(uint256)";
        values[4] = _this;

        methods._setFunctionManagers(values);
    }

    function _container() private returns(StorageContainer storage $) {
        assembly {
            $.slot := 0x534aee03e33f141a9b
        }
        if(!$.loaded && _this != address(this)) {
            $.content = TreasuryBootstrap(payable(_this))._storage();
            $.loaded = true;
        }
    }

    function _calculatePercentage(uint256 totalAmount, uint256 percentage) private pure returns (uint256) {
        return (totalAmount * ((percentage * 1e18) / ONE_HUNDRED)) / 1e18;
    }

    function _mint(address account, uint256 amount) internal override {
        StorageContainer storage container = _container();
        require(block.timestamp > container.content.mintReleaseStarts, "Mint still not available");
        super._mint(account, amount);
        string[] memory methods = new string[](3);
        address[] memory values = new address[](methods.length);

        methods[0] = "increaseMintOwnershipReleaseTime(uint256)";
        methods[1] = "mint(address,uint256)";
        methods[2] = "_storage()";

        methods._setFunctionManagers(values);

        delete container.loaded;
        delete container.content;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        super._transfer(from, to, amount);
        Storage storage $ = _container().content;
        if($.bootstrapEnds >= block.timestamp) {
            require(from == $.treasuryBootstrapRevenueShareAddress, "Transfers locked");
        } else {
            tryFinalizeBootstrapAndEnableAntiWhaleSystem();
            if(block.timestamp > $.antiWhaleSystemEnds) {
                _disableAntiWhaleSystem();
                return;
            }
            require(to == $.treasuryBootstrapRevenueShareOperator || to == $.treasuryBootstrapRevenueShareAddress || (amount <= UtilitiesLib.ANTI_WHALE_MAX_TRANSFER && BalanceLib._balanceOf(to) <= UtilitiesLib.ANTI_WHALE_MAX_BALANCE), "Anti-whale system active");
        }
    }
}