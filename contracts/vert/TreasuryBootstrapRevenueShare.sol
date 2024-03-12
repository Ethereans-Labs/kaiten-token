// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ITreasuryBootstrapRevenueShare.sol";
import "@ethereansos/farming-base/contracts/BaseFarming.sol";
import "./UtilitiesLib.sol";
import "./uniswapV3/IPeripheryImmutableState.sol";
import "./uniswapV3/INonfungiblePositionManager.sol";
import "./uniswapV3/IUniswapV3Factory.sol";
import "./uniswapV3/ISwapRouter.sol";
import "./uniswapV3/IPoolInitializer.sol";
import "../model/IERC20Approve.sol";
import "../impl/Ownable.sol";

library TreasuryBootstrapRevenueShareLib {

    function collectFees(bytes memory conversionInput, address uniswapV3NonfungiblePositionsManager, address token, address WETH, uint256 tokenId, address conversionAddress, uint24 fee, address uniswapV3SwapRouter) external returns(uint256 collectedAmount0, uint256 collectedAmount1, bytes memory conversionOutput) {
        bytes[] memory data = new bytes[](3);
        INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(uniswapV3NonfungiblePositionsManager);
        data[0] = abi.encodeWithSelector(nonfungiblePositionManager.collect.selector, INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(0),
            amount0Max: 0xffffffffffffffffffffffffffffffff,
            amount1Max: 0xffffffffffffffffffffffffffffffff
        }));
        data[1] = abi.encodeWithSelector(nonfungiblePositionManager.unwrapWETH9.selector, 0, address(this));
        data[2] = abi.encodeWithSelector(nonfungiblePositionManager.sweepToken.selector, token, 0, conversionAddress != address(0) ? conversionAddress : address(this));
        (collectedAmount0, collectedAmount1) = abi.decode(IMulticall(uniswapV3NonfungiblePositionsManager).multicall(data)[0], (uint256, uint256));

        uint256 amount = token < WETH ? collectedAmount0 : collectedAmount1;

        if(amount > 0) {
            conversionOutput = _convertAmountInETH(amount, conversionInput, token, WETH, conversionAddress, fee, uniswapV3SwapRouter);
        }
    }

    function _convertAmountInETH(uint256 amount, bytes memory conversionInput, address token, address WETH, address conversionAddress, uint24 fee, address uniswapV3SwapRouter) private returns(bytes memory conversionOutput) {

        if(conversionAddress != address(0)) {
            uint256 codeLength;
            assembly {
                codeLength := extcodesize(conversionAddress)
            }
            if(codeLength > 0) {
                return IConvertInETH(conversionAddress).convert(token, amount, conversionInput);
            } else {
                return "";
            }
        }

        (uint24 _fee, uint256 amountOutMinimum) = abi.decode(conversionInput, (uint24, uint256));

        ISwapRouter swapRouter = ISwapRouter(uniswapV3SwapRouter);

        IERC20Approve(token).approve(address(swapRouter), amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(swapRouter.exactInput.selector, ISwapRouter.ExactInputParams({
            path : abi.encodePacked(token, _fee == 0 ? fee : _fee, WETH),
            recipient : address(0),
            deadline : block.timestamp + 10000,
            amountIn : amount,
            amountOutMinimum : amountOutMinimum
        }));
        data[1] = abi.encodeWithSelector(swapRouter.unwrapWETH9.selector, 0, address(this));
        conversionOutput = swapRouter.multicall(data)[0];
    }

    function _safeTransfer(address tokenAddress, address to, uint256 value) internal {
        if(value == 0) {
            return;
        }
        if(to == address(this)) {
            return;
        }
        if(tokenAddress == address(0)) {
            require(_sendETH(to, value), 'FARMING: TRANSFER_FAILED');
            return;
        }
        if(to == address(0)) {
            return _safeBurn(tokenAddress, value);
        }
        (bool success, bytes memory data) = tokenAddress.call(abi.encodeWithSelector(IERC20Token(address(0)).transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'FARMING: TRANSFER_FAILED');
    }

    function _safeBurn(address erc20TokenAddress, uint256 value) internal {
        (bool result, bytes memory returnData) = erc20TokenAddress.call(abi.encodeWithSelector(0x42966c68, value));//burn(uint256)
        result = result && (returnData.length == 0 || abi.decode(returnData, (bool)));
        if(!result) {
            (result, returnData) = erc20TokenAddress.call(abi.encodeWithSelector(IERC20Token(erc20TokenAddress).transfer.selector, address(0), value));
            result = result && (returnData.length == 0 || abi.decode(returnData, (bool)));
        }
        if(!result) {
            (result, returnData) = erc20TokenAddress.call(abi.encodeWithSelector(IERC20Token(erc20TokenAddress).transfer.selector, 0x000000000000000000000000000000000000dEaD, value));
            result = result && (returnData.length == 0 || abi.decode(returnData, (bool)));
        }
        if(!result) {
            (result, returnData) = erc20TokenAddress.call(abi.encodeWithSelector(IERC20Token(erc20TokenAddress).transfer.selector, 0xdeaDDeADDEaDdeaDdEAddEADDEAdDeadDEADDEaD, value));
            result = result && (returnData.length == 0 || abi.decode(returnData, (bool)));
        }
    }

    function _sendETH(address to, uint256 value) private returns(bool) {
        assembly {
            let res := call(gas(), to, value, 0, 0, 0, 0)
        }
        return true;
    }
}

contract TreasuryBootstrapRevenueShare is ITreasuryBootstrapRevenueShare, Ownable, BaseFarming {

    uint256 public constant MONTH_IN_SECONDS = 2628000;

    struct AccountPosition {
        uint256 vestedAmount;
        uint256 ethAmount;
        uint128 positionLiquidity;
        uint256 farmingBalance;
    }
    uint256 public accounts;

    address public immutable destinationAddress;
    address public immutable uniswapV3NonfungiblePositionsManager;
    address public immutable uniswapV3SwapRouter;
    address public immutable WETH;

    address public pool;

    uint24 public immutable fee;
    uint160 public immutable sqrtPriceX96;
    int24 public tickLower;
    int24 public tickUpper;
    uint256 public vestingEnds;
    uint256 public priceSlippagePercentage;

    mapping(address => AccountPosition) public positionOf;

    uint256 public farmingDuration;

    address public token;

    address public treasuryAddress;

    uint256 public treasuryFarmingBalance;

    uint256 public tokenId;

    address public conversionAddress;

    uint256 public redeemableETH;

    constructor(address initialOwner, address _destinationAddress, address _conversionAddress, uint256 _farmingDuration, address _uniswapV3NonfungiblePositionsManager, address _uniswapV3SwapRouter, uint24 _fee, uint160 _sqrtPriceX96, uint256 _priceSlippagePercentage, int24 _tickLower, int24 _tickUpper) Ownable(initialOwner) {
        _inhibitCallback = true;
        _initialize(address(this), MONTH_IN_SECONDS * (farmingDuration = _farmingDuration));
        destinationAddress = _destinationAddress;
        conversionAddress = _conversionAddress;
        WETH = IPeripheryImmutableState(uniswapV3NonfungiblePositionsManager = _uniswapV3NonfungiblePositionsManager).WETH9();
        uniswapV3SwapRouter = _uniswapV3SwapRouter;
        tickLower = _tickLower;
        tickUpper = _tickUpper;
        fee = _fee;
        sqrtPriceX96 = _sqrtPriceX96;
        priceSlippagePercentage = _priceSlippagePercentage;
    }

    receive() external payable {
        _receive();
    }

    function onERC721Received(address,address,uint256,bytes calldata) external view returns (bytes4) {
        require(tokenId == 0);
        return this.onERC721Received.selector;
    }

    function setPriceSlippagePercentage(uint256 newValue) external onlyOwner {
        priceSlippagePercentage = newValue;
    }

    function setConversionAddress(address newValue) external onlyOwner returns(address oldValue) {
        oldValue = conversionAddress;
        conversionAddress = newValue;
    }

    function completeInitialization(address _treasuryAddress) override external returns(address operatorAddress) {
        require(token == address(0));
        treasuryAddress = _treasuryAddress;
        uint256 tokenPosition = (token = msg.sender) < WETH ? 0 : 1;
        return pool = IPoolInitializer(uniswapV3NonfungiblePositionsManager).createAndInitializePoolIfNecessary(
            tokenPosition == 0 ? msg.sender : WETH,
            tokenPosition == 1 ? msg.sender : WETH,
            fee,
            sqrtPriceX96
        );
    }

    function updatePositionOf(address account, uint256 amount, uint256 vestedAmount) override external payable {

        require(msg.sender == token);

        _increaseReservedBalance(msg.value);
        redeemableETH += msg.value;

        AccountPosition storage _accountPosition = positionOf[account];
        if(_accountPosition.ethAmount == 0) {
            accounts++;
        }

        _accountPosition.ethAmount += msg.value;

        (uint128 liquidity, uint256 remainingAmount) = _mintOrIncreaseLiquidity(amount);

        amount += vestedAmount;

        _accountPosition.vestedAmount += vestedAmount + remainingAmount;
        _accountPosition.positionLiquidity += liquidity;

        _accountPosition.farmingBalance += amount;
        totalFarmingLiquidity += amount;
        require(_accountPosition.farmingBalance <= UtilitiesLib.ANTI_WHALE_MAX_BALANCE, "Anti-whale system active");

        _sync(address(0), account, 0, _accountPosition.farmingBalance, totalFarmingLiquidity);
    }

    function finalizePosition(uint256 treasuryBalance, uint256 additionalLiquidity, uint256 _vestingEnds) external payable {
        require(msg.sender == token);
        vestingEnds = _vestingEnds;
        (,uint256 remainingAmount) = _mintOrIncreaseLiquidity(treasuryBalance + additionalLiquidity);
        if(remainingAmount > 0) {
            _safeBurn(token, remainingAmount);
        }

        treasuryFarmingBalance += treasuryBalance;
        totalFarmingLiquidity += treasuryBalance;
        address[] memory rewardReceivers = new address[](1);
        _sync(address(0), rewardReceivers[0] = treasuryAddress, 0, treasuryFarmingBalance, totalFarmingLiquidity);
        _claimReward(rewardReceivers[0], rewardReceivers, new uint256[](0));
    }

    function redeemVestingResult() external {
        AccountPosition storage _accountPosition = positionOf[msg.sender];
        uint256 vestedAmount = _accountPosition.vestedAmount;
        uint256 ethAmount = _accountPosition.ethAmount;
        require(vestedAmount != 0 && ethAmount != 0, "unknown account");
        _accountPosition.vestedAmount = 0;
        _accountPosition.ethAmount = 0;
        address[] memory rewardReceivers = new address[](1);
        if(vestingEnds == 0 || block.timestamp < vestingEnds) {
            _decreaseReservedBalance(ethAmount);
            redeemableETH -= ethAmount;
            _safeTransfer(address(0), msg.sender, ethAmount);
            _safeBurn(token, vestedAmount);
            totalFarmingLiquidity -= _accountPosition.farmingBalance;
            _sync(msg.sender, address(0), _accountPosition.farmingBalance = 0, 0, totalFarmingLiquidity);
            rewardReceivers[0] = treasuryAddress;
            delete positionOf[msg.sender];
            accounts--;
        } else {
            _safeTransfer(token, rewardReceivers[0] = msg.sender, vestedAmount);
            sendRemainingETH();
        }
        _claimReward(msg.sender, rewardReceivers, new uint256[](0));
    }

    modifier afterVestingPeriod() {
        _afterVestingPeriod();
        _;
    }

    function sendRemainingETH() public afterVestingPeriod {
        _sendRemainingETH();
    }

    function setTreasuryAddress(address newValue) external afterVestingPeriod returns(address oldValue) {
        require((oldValue = treasuryAddress) == msg.sender, "unauthorized");
        treasuryAddress = newValue;
        _sync(oldValue, newValue, 0, treasuryFarmingBalance, totalFarmingLiquidity);
        address[] memory rewardReceivers = new address[](1);
        rewardReceivers[0] = newValue;
        _claimReward(oldValue, rewardReceivers, new uint256[](0));
    }

    function claimReward(address[] memory rewardReceivers, uint256[] memory rewardReceiversPercentage) external afterVestingPeriod  returns(uint256 claimedReward, uint256 _nextRebalanceEvent, uint256 rewardPerEvent_) {
        return _claimReward(msg.sender, rewardReceivers, rewardReceiversPercentage);
    }

    function claimRewardOf(address account) external afterVestingPeriod returns(uint256 claimedReward, uint256 _nextRebalanceEvent, uint256 rewardPerEvent_) {
        address[] memory rewardReceivers = new address[](1);
        return _claimReward(rewardReceivers[0] = account, rewardReceivers, new uint256[](0));
    }

    function redeemRevenueSharePositionForever(uint256 amount0Min, uint256 amount1Min) external afterVestingPeriod returns (uint256 amount0, uint256 amount1) {
        AccountPosition storage _accountPosition = positionOf[msg.sender];
        require(_accountPosition.positionLiquidity != 0, "unknown account");
        uint256 vestedAmount = _accountPosition.vestedAmount;
        _accountPosition.vestedAmount = 0;
        _accountPosition.ethAmount = 0;
        if(vestedAmount != 0) {
            _safeTransfer(token, msg.sender, vestedAmount);
        }
        address to = address(0);
        uint256 toBalance = 0;
        if(farmingDuration == 1) {
            to = treasuryAddress;
            treasuryFarmingBalance += _accountPosition.farmingBalance;
            toBalance = treasuryFarmingBalance;
        } else {
            totalFarmingLiquidity -= _accountPosition.farmingBalance;
        }
        _sync(msg.sender, to, _accountPosition.farmingBalance = 0, toBalance, totalFarmingLiquidity);
        address[] memory rewardReceivers = new address[](1);
        rewardReceivers[0] = msg.sender;
        _claimReward(msg.sender, rewardReceivers, new uint256[](0));

        bytes[] memory data = new bytes[](3);
        INonfungiblePositionManager nonfungiblePositionManager = INonfungiblePositionManager(uniswapV3NonfungiblePositionsManager);

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: _accountPosition.positionLiquidity,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline : block.timestamp + 1000
        }));

        delete positionOf[msg.sender];
        accounts--;

        data[0] = abi.encodeWithSelector(nonfungiblePositionManager.collect.selector, INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(0),
            amount0Max: uint128(amount0),
            amount1Max: uint128(amount1)
        }));
        data[1] = abi.encodeWithSelector(nonfungiblePositionManager.unwrapWETH9.selector, 0, msg.sender);
        data[2] = abi.encodeWithSelector(nonfungiblePositionManager.sweepToken.selector, token, 0, msg.sender);
        (amount0, amount1) = abi.decode(IMulticall(uniswapV3NonfungiblePositionsManager).multicall(data)[0], (uint256, uint256));
    }

    function collectFees(bytes memory conversionInput) external returns(uint256 collectedAmount0, uint256 collectedAmount1, bytes memory conversionOutput) {
        (collectedAmount0, collectedAmount1, conversionOutput) = TreasuryBootstrapRevenueShareLib.collectFees(conversionInput, uniswapV3NonfungiblePositionsManager, token, WETH, tokenId, conversionAddress, fee, uniswapV3SwapRouter);
        _afterVestingPeriod();
    }

    function _mintOrIncreaseLiquidity(uint256 amount) private returns(uint128 liquidity, uint256 remainingAmount) {

        uint256 tokenPosition = token < WETH ? 0 : 1;

        IERC20Approve(token).approve(uniswapV3NonfungiblePositionsManager, amount);

        (uint256 amount0, uint256 amount1) = tokenPosition == 0 ? (amount, uint256(0)) : (uint256(0), amount);

        if(tokenId == 0) {
            (tokenId, liquidity, amount0, amount1) = INonfungiblePositionManager(uniswapV3NonfungiblePositionsManager).mint(INonfungiblePositionManager.MintParams({
                token0: tokenPosition == 0 ? token : WETH,
                token1: tokenPosition == 1 ? token : WETH,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: _calculatePercentage(amount0, FULL_PRECISION - priceSlippagePercentage),
                amount1Min: _calculatePercentage(amount1, FULL_PRECISION - priceSlippagePercentage),
                recipient: address(this),
                deadline: block.timestamp + 10000
            }));
        } else {
            (liquidity, amount0, amount1) = INonfungiblePositionManager(uniswapV3NonfungiblePositionsManager).increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: _calculatePercentage(amount0, FULL_PRECISION - priceSlippagePercentage),
                amount1Min: _calculatePercentage(amount1, FULL_PRECISION - priceSlippagePercentage),
                deadline: block.timestamp + 10000
            }));
        }
        remainingAmount = (amount - (tokenPosition == 0 ? amount0 : amount1));
    }

    function _sendRemainingETH() private {
        uint256 _redeemableETH = redeemableETH;
        if(_redeemableETH != 0) {
            redeemableETH = 0;
            _decreaseReservedBalance(_redeemableETH);
            _safeTransfer(address(0), destinationAddress, _redeemableETH);
        }
    }

    function _afterVestingPeriod() private {
        require(vestingEnds != 0 && block.timestamp >= vestingEnds, "in vesting period");
        _sendRemainingETH();
        if(nextRebalanceEvent != 0 && block.timestamp >= nextRebalanceEvent && farmingDuration != 1) {
            rebalanceIntervalInEventSlots = (MONTH_IN_SECONDS * (farmingDuration = (farmingDuration /= 2) == 0 ? 1 : farmingDuration)) / TIME_SLOT_IN_SECONDS;
        }
        address[] memory rewardReceivers = new address[](1);
        _claimReward(rewardReceivers[0] = treasuryAddress, rewardReceivers, new uint256[](0));
    }
}

interface IConvertInETH {
    function convert(address tokenAddress, uint256 amount, bytes calldata conversionInput) external returns(bytes memory conversionOutput);
}