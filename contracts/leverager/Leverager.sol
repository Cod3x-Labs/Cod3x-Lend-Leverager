// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IOracle.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/IFlashLoanReceiver.sol";
import "./lib/WadRayMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Leverager is IFlashLoanReceiver {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;

    IOracle public immutable ORACLE;
    ILendingPool public immutable override LENDING_POOL;
    ILendingPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
    uint256 public constant MIN_HF = 1.1e18;

    error InvalidInput();
    error InvalidHealthFactor();
    error UnauthorizedInitiator();

    constructor(address _addressesProvider) public {
        ADDRESSES_PROVIDER = ILendingPoolAddressesProvider(_addressesProvider);
        LENDING_POOL = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());
        ORACLE = IOracle(ADDRESSES_PROVIDER.getPriceOracle());
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
            abi.encode(msg.sender, _initialDeposit, _minHealthFactor),
            0 // referral code
        );
    }

    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] calldata ,
        address _initiator,
        bytes calldata _params
    ) external override returns (bool) {
        if (_initiator != address(this)) revert UnauthorizedInitiator();

        (address onBehalfOf, uint256 initialDeposit, uint256 minHealthFactor) = abi.decode(_params, (address, uint256, uint256));

        uint256 amountToDeposit = initialDeposit + _amounts[0];
        IERC20(_assets[0]).safeTransferFrom(onBehalfOf, address(this), initialDeposit);
        IERC20(_assets[0]).approve(address(LENDING_POOL), amountToDeposit);
        
        LENDING_POOL.deposit(
            _assets[0],
            amountToDeposit,
            onBehalfOf,
            0
        );

        if (getFutureHF(onBehalfOf, _assets[0], _amounts[0]) < minHealthFactor) revert InvalidHealthFactor();

        return true;
    }

    function getFutureHF(address _user, address _asset, uint256 _amountBorrowed) public view returns(uint256){
        (uint256 totalCollateralUSD, uint256 totalDebtUSD,,,,) = LENDING_POOL.getUserAccountData(_user);  
        uint256 flashLoanDebtUSD = (_amountBorrowed * ORACLE.getAssetPrice(_asset)) / 1e18;
        return totalCollateralUSD.wadDiv(totalDebtUSD - flashLoanDebtUSD);
    }
}