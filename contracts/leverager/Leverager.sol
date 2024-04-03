// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/IFlashLoanReceiver.sol";
import "./interfaces/IWETH.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Leverager is IFlashLoanReceiver {
    using SafeERC20 for IERC20;

    IWETH public immutable weth;
    ILendingPool private immutable lendingPool;
    ILendingPoolAddressesProvider private immutable addressesProvider;
    uint256 public constant MIN_HF = 1.05e18;

    error Leverager__INVALID_INPUT();
    error Leverager__INVALID_HEALTH_FACTOR();
    error Leverager__UNAUTHORIZED_CALLER();
    error Leverager__TRANSFER_FAILED();
    error Leverager__INVALID_INITIATOR();
    error Leverager__NATIVE_LEVERAGE_NOT_ACTIVATED();

    constructor(address _addressesProvider, address _weth) {
        if (_addressesProvider == address(0)) revert Leverager__INVALID_INPUT();
        addressesProvider = ILendingPoolAddressesProvider(_addressesProvider);
        lendingPool = ILendingPool(addressesProvider.getLendingPool());
        weth = IWETH(_weth);
    }

    function leverageNative(
        uint256 _borrowAmount,
        uint256 _minHealthFactor
    ) external payable {
        if (address(weth) == address(0)) revert Leverager__NATIVE_LEVERAGE_NOT_ACTIVATED();
        if (msg.value != 0)
            weth.deposit{value: msg.value}();
        _leverage(address(weth), msg.value, _borrowAmount, _minHealthFactor);
    }

    function leverageERC20(
        address _asset,
        uint256 _initialDeposit,
        uint256 _borrowAmount,
        uint256 _minHealthFactor
    ) external {
        if (_initialDeposit != 0) 
            IERC20(_asset).safeTransferFrom(msg.sender, address(this), _initialDeposit);
        _leverage(_asset, _initialDeposit, _borrowAmount, _minHealthFactor);
    }

    function deleverageNative() external {
        if (address(weth) == address(0)) revert Leverager__NATIVE_LEVERAGE_NOT_ACTIVATED();
        _deleverage(address(weth));
        weth.withdraw(weth.balanceOf(address(this)));
        (bool success_, ) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success_) revert Leverager__TRANSFER_FAILED();
    }

    function deleverageERC20(
        address _asset
    ) external {
        _deleverage(_asset);
        uint256 assetBalance_ = IERC20(_asset).balanceOf(address(this));
        if (assetBalance_ != 0)
            IERC20(_asset).safeTransfer(msg.sender, assetBalance_);
    }

    /**
     * @notice leverage an asset using flashloan.
     * @dev Before calling _leverage() users will need to call: 
     *     - DebtToken.approveDelegation(address(Leverager), _borrowAmount)
     *     - ERC20(_asset).approve(address(Leverager), _initialDeposit)
     * @param _asset to leverage
     * @param _initialDeposit amount to send 
     * @param _borrowAmount amount to borrow
     * @param _minHealthFactor minimum hf
     */
    function _leverage(
        address _asset,
        uint256 _initialDeposit,
        uint256 _borrowAmount,
        uint256 _minHealthFactor
    ) internal {
        if (_asset == address(0)) revert Leverager__INVALID_INPUT();
        if (_borrowAmount == 0) revert Leverager__INVALID_INPUT();
        if (_minHealthFactor < MIN_HF) revert Leverager__INVALID_HEALTH_FACTOR();

        address[] memory assets_ = new address[](1);
        assets_[0] = _asset;

        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = _borrowAmount;

        uint256[] memory modes_ = new uint256[](1);
        modes_[0] = 2;

        lendingPool.flashLoan(
            address(this),
            assets_, // [_asset]
            amounts_,// [_borrowAmount]
            modes_,  // [2] variable debt
            msg.sender, // onBehalfOf
            abi.encode(true, msg.sender, _initialDeposit),
            0 // referral code
        );

        (,,,,, uint256 healthFactor_) = lendingPool.getUserAccountData(msg.sender);
        if (healthFactor_ < _minHealthFactor) revert Leverager__INVALID_HEALTH_FACTOR();
    }

    /**
     * @notice deleverage an asset using flashloan.
     * @dev Before calling loop() users will need to call: 
     *     - ERC20(aToken).approve(address(this), type(uint256).max) 
     * @param _asset to deleverage
     */
    function _deleverage(
        address _asset
    ) internal {
        if (_asset == address(0)) revert Leverager__INVALID_INPUT();

        address debtToken_ = lendingPool.getReserveData(_asset).variableDebtTokenAddress;

        address[] memory assets_ = new address[](1);
        assets_[0] = _asset;

        uint256[] memory amounts_ = new uint256[](1);
        amounts_[0] = IERC20(debtToken_).balanceOf(msg.sender);

        uint256[] memory modes_ = new uint256[](1);
        modes_[0] = 0;

        lendingPool.flashLoan(
            address(this),
            assets_, // [_asset]
            amounts_,// [_borrowAmount]
            modes_,  // [0] no debt
            msg.sender, // onBehalfOf
            abi.encode(false, msg.sender, 0),
            0 // referral code
        );
    }

    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes calldata _params
    ) external override returns (bool) {
        if (_initiator != address(this)) revert Leverager__INVALID_INITIATOR();

        (bool isLeveraging, address sender_, uint256 initialDeposit_) 
            = abi.decode(_params, (bool, address, uint256));

        // leverage
        if (isLeveraging) {
            uint256 amountToDeposit_ = initialDeposit_ + _amounts[0];
            IERC20(_assets[0]).approve(address(lendingPool), amountToDeposit_);
            lendingPool.deposit(
                _assets[0],
                amountToDeposit_,
                sender_,
                0
            );
        }
        // deleverage
        else {
            address aToken_ = lendingPool.getReserveData(_assets[0]).aTokenAddress;
            IERC20(_assets[0]).approve(address(lendingPool), _amounts[0]);
            
            lendingPool.repay(
                _assets[0],
                _amounts[0],
                2, // variable
                sender_
            );

            IERC20(aToken_).safeTransferFrom(sender_, address(this), IERC20(aToken_).balanceOf(sender_));

            lendingPool.withdraw(
                _assets[0],
                IERC20(aToken_).balanceOf(address(this)),
                address(this)
            );

            // repay flashloan
            IERC20(_assets[0]).approve(address(lendingPool), _amounts[0] + _premiums[0]);
        }

        return true;
    }

    function ADDRESSES_PROVIDER() external view returns (ILendingPoolAddressesProvider) {
        return addressesProvider;
    }

    function LENDING_POOL() external view returns (ILendingPool) {
        return lendingPool;
    }

    receive() external payable {
        require(msg.sender == address(weth), 'Receive not allowed');
    }

    fallback() external payable {
        revert('Fallback not allowed');
    }
}