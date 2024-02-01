// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/IFlashLoanReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Leverager is IFlashLoanReceiver {
    using SafeERC20 for IERC20;


    ILendingPool public immutable override LENDING_POOL;
    ILendingPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
    uint256 public constant MIN_HF = 1.1e18;

    error InvalidInput();
    error InvalidHealthFactor();
    error UnauthorizedInitiator();

    constructor(address _addressesProvider) public {
        ADDRESSES_PROVIDER = ILendingPoolAddressesProvider(_addressesProvider);
        LENDING_POOL = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());
    }

    function loop(
        address _asset,
        uint256 _initialDeposit,
        uint256 _borrowAmount,
        uint256 _minHealthFactor
    ) external {
        if (_asset == address(0)) revert InvalidInput();
        if (_initialDeposit == 0) revert InvalidInput();
        if (_borrowAmount == 0) revert InvalidInput();
        if (_minHealthFactor < MIN_HF) revert InvalidHealthFactor();

        address[] memory assets = new address[](1);
        assets[0] = _asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _borrowAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 2;

        LENDING_POOL.flashLoan(
            address(this),
            assets, // [_asset]
            amounts,// [_borrowAmount]
            modes,  // [2]
            msg.sender, // onBehalfOf
            abi.encode(msg.sender, _initialDeposit),
            0 // referral code
        );

        (,,,,, uint256 healthFactor) = LENDING_POOL.getUserAccountData(msg.sender);
        if (healthFactor < _minHealthFactor) revert InvalidHealthFactor();
    }

    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] calldata ,
        address _initiator,
        bytes calldata _params
    ) external override returns (bool) {
        if (_initiator != address(this)) revert UnauthorizedInitiator();

        (address onBehalfOf, uint256 initialDeposit) = abi.decode(_params, (address, uint256));


        uint256 amountToDeposit = initialDeposit + _amounts[0];
        IERC20(_assets[0]).safeTransferFrom(onBehalfOf, address(this), initialDeposit);
        IERC20(_assets[0]).approve(address(LENDING_POOL), amountToDeposit);
        
        LENDING_POOL.deposit(
            _assets[0],
            amountToDeposit,
            onBehalfOf,
            0
        );

        return true;
    }
}