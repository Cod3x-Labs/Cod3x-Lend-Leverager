// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/IFlashLoanReceiver.sol";

contract Leverager is IFlashLoanReceiver {
    using SafeMath for uint256;

    ILendingPool public immutable override LENDING_POOL;
    ILendingPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;

    uint256 private flashLoanStatus;
    uint256 private constant NO_FL_IN_PROGRESS = 0;
    uint256 private constant DEPOSIT_FL_IN_PROGRESS = 1;

    constructor(address _lendingPool, address _addressesProvider) public {
        LENDING_POOL = ILendingPool(_lendingPool);
        ADDRESSES_PROVIDER = ILendingPoolAddressesProvider(_addressesProvider);
    }

    function loop(
        address asset,
        uint256 initialDeposit,
        uint256 borrowAmount
    ) external {
        require(asset != address(0), 'INVALID_ADDRESS');
        IERC20(asset).transferFrom(msg.sender, address(this), initialDeposit);
        IERC20(asset).approve(address(LENDING_POOL), type(uint256).max);
        LENDING_POOL.deposit(
            asset,
            initialDeposit,
            msg.sender,
            0
        );
        _initFlashLoan(
            asset,
            msg.sender,
            borrowAmount,
            DEPOSIT_FL_IN_PROGRESS
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        require(initiator == address(this), "!initiator");
        require(flashLoanStatus == DEPOSIT_FL_IN_PROGRESS, "invalid flashLoanStatus");
        flashLoanStatus = NO_FL_IN_PROGRESS;

        address onBehalfOf = abi.decode(params, (address));
        IERC20(assets[0]).approve(address(LENDING_POOL), amounts[0]);
        LENDING_POOL.deposit(
            assets[0],
            amounts[0],
            onBehalfOf,
            0
        );

        return true;
    }

    function _initFlashLoan(
        address asset,
        address onBehalf,
        uint256 amount,
        uint256 newLoanStatus
    ) internal {
        require(amount != 0, "FL: invalid amount!");

        // asset to be flashed
        address[] memory assets = new address[](1);
        assets[0] = address(asset);

        // amount to be flashed
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = 2;

        flashLoanStatus = newLoanStatus;
        LENDING_POOL.flashLoan(
            address(this),
            assets,
            amounts,
            modes,
            onBehalf,
            abi.encode(onBehalf),
            0 // referral code
        );
    }
}