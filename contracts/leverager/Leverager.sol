// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/ILendingPool.sol";

contract Leverager {
    using SafeMath for uint256;

    uint256 public constant BORROW_RATIO_DECIMALS = 4;

    /// @notice Lending Pool address
    ILendingPool public lendingPool;

    constructor(ILendingPool _lendingPool) public {
        lendingPool = _lendingPool;
    }

    /**
     * @dev Returns the configuration of the reserve
     * @param asset The address of the underlying asset of the reserve
     * @return The configuration of the reserve
     **/
    function getConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory) {
        return lendingPool.getConfiguration(asset);
    }

    /**
     * @dev Returns variable debt token address of asset
     * @param asset The address of the underlying asset of the reserve
     * @return varaiableDebtToken address of the asset
     **/
    function getVariableDebtToken(address asset) public view returns (address) {
        DataTypes.ReserveData memory reserveData = lendingPool.getReserveData(asset);
        return reserveData.variableDebtTokenAddress;
    }

    /**
     * @dev Returns loan to value
     * @param asset The address of the underlying asset of the reserve
     * @return ltv of the asset
     **/
    function ltv(address asset) public view returns (uint256) {
        DataTypes.ReserveConfigurationMap memory config =  lendingPool.getConfiguration(asset);
        return config.data % (2 ** 16);
    }

    /**
     * @dev Loop the deposit and borrow of an asset
     * @param asset for loop
     * @param amount for the initial deposit
     * @param borrowRatio Ratio of tokens to borrow
     * @param loopCount Repeat count for loop
     **/
    function loop(
        address asset,
        uint256 amount,
        uint256 borrowRatio,
        uint256 loopCount
    ) external {
        require(address(asset) != address(0), 'INVALID_ADDRESS');
        uint256 interestRateMode = 2;
        uint16 referralCode = 0;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(lendingPool), type(uint256).max);
        lendingPool.deposit(asset, amount, msg.sender, referralCode);
        for (uint256 i = 0; i < loopCount; ++i) {
            amount = amount.mul(borrowRatio).div(10 ** BORROW_RATIO_DECIMALS);
            lendingPool.borrow(asset, amount, interestRateMode, referralCode, msg.sender);
            lendingPool.deposit(asset, amount, msg.sender, referralCode);
        }
    }
}