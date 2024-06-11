// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import "forge-std/Test.sol";

// import "contracts/leverager/interfaces/IERC20.sol";

import "contracts/leverager/Leverager.sol";
import "contracts/leverager/interfaces/IDebtTokenBase.sol";
import "contracts/leverager/interfaces/ILendingPool.sol";
import "contracts/leverager/interfaces/ILendingPoolAddressesProvider.sol";
import "./Constants.sol";

contract LeveragerTest is Test, Constants {
    Leverager l;
    address alice = address(0xa11ce);
    uint initialMint = 33 ether;

    address aweth;
    address wethDebtToken;

    // uint256 forkIdEth;
    // uint256 forkIdArb;

    function setUp() public {
        // forkIdEth = vm.createFork("https://eth.llamarpc.com");
        // forkIdArb = vm.createFork("https://arbitrum.llamarpc.com");

        aweth = ILendingPool(ILendingPoolAddressesProvider(addressesProvider).getLendingPool())
                    .getReserveData(weth).aTokenAddress;
        wethDebtToken = ILendingPool(ILendingPoolAddressesProvider(addressesProvider).getLendingPool())
                    .getReserveData(weth).variableDebtTokenAddress;

        l = new Leverager(addressesProvider, weth);
        deal({ token: weth, to: alice, give: initialMint });
        deal(alice, initialMint);
    }

    function test_leverageERC20(uint initialDeposit, uint borrowAmount) public {
        vm.assume(initialDeposit > 1e8);
        vm.assume(initialDeposit < initialMint);
        vm.assume(borrowAmount < initialDeposit);
        vm.assume(borrowAmount != 0);

        vm.startPrank(alice);
        IERC20(weth).approve(address(l), initialDeposit);
        IDebtTokenBase(wethDebtToken).approveDelegation(address(l), borrowAmount);
        l.leverageERC20(weth, initialDeposit, borrowAmount, 1.2e18);

        assertApproxEqAbs(IERC20(weth).balanceOf(alice), initialMint - initialDeposit, 1, "1");
        assertApproxEqAbs(IERC20(aweth).balanceOf(alice), initialDeposit + borrowAmount, 1, "2");
        assertApproxEqAbs(IERC20(wethDebtToken).balanceOf(alice), borrowAmount, 1, "3");

        assertEq(IERC20(weth).balanceOf(address(l)), 0, "4");
        assertEq(IERC20(aweth).balanceOf(address(l)), 0, "5");
        assertEq(IERC20(wethDebtToken).balanceOf(address(l)), 0, "6");
    }

    function test_leverageERC20PostDeposit(uint initialDeposit, uint borrowAmount) public {
        vm.assume(initialDeposit > 1e8);
        vm.assume(initialDeposit < initialMint);
        vm.assume(borrowAmount < initialDeposit);
        vm.assume(borrowAmount != 0);

        vm.startPrank(alice);
        IERC20(weth).approve(address(l.LENDING_POOL()), initialDeposit);
        l.LENDING_POOL().deposit(weth, initialDeposit, alice, 0);
        IDebtTokenBase(wethDebtToken).approveDelegation(address(l), borrowAmount);
        l.leverageERC20(weth, 0, borrowAmount, 1.2e18);

        assertApproxEqAbs(IERC20(weth).balanceOf(alice), initialMint - initialDeposit, 1, "1");
        assertApproxEqAbs(IERC20(aweth).balanceOf(alice), initialDeposit + borrowAmount, 1, "2");
        assertApproxEqAbs(IERC20(wethDebtToken).balanceOf(alice), borrowAmount, 1, "3");

        assertEq(IERC20(weth).balanceOf(address(l)), 0, "4");
        assertEq(IERC20(aweth).balanceOf(address(l)), 0, "5");
        assertEq(IERC20(wethDebtToken).balanceOf(address(l)), 0, "6");
    }

    function test_leverageNativePostDepositERC20(uint initialDeposit, uint borrowAmount) public {
        vm.assume(initialDeposit > 1e8);
        vm.assume(initialDeposit < initialMint);
        vm.assume(borrowAmount < initialDeposit);
        vm.assume(borrowAmount != 0);

        vm.startPrank(alice);
        IERC20(weth).approve(address(l.LENDING_POOL()), initialDeposit);
        l.LENDING_POOL().deposit(weth, initialDeposit, alice, 0);
        IDebtTokenBase(wethDebtToken).approveDelegation(address(l), borrowAmount);
        l.leverageNative(borrowAmount, 1.2e18);

        assertApproxEqAbs(IERC20(weth).balanceOf(alice), initialMint - initialDeposit, 1, "1");
        assertApproxEqAbs(IERC20(aweth).balanceOf(alice), initialDeposit + borrowAmount, 1, "2");
        assertApproxEqAbs(IERC20(wethDebtToken).balanceOf(alice), borrowAmount, 1, "3");

        assertEq(IERC20(weth).balanceOf(address(l)), 0, "4");
        assertEq(IERC20(aweth).balanceOf(address(l)), 0, "5");
        assertEq(IERC20(wethDebtToken).balanceOf(address(l)), 0, "6");
    }

    function test_leverageNative(uint initialDeposit, uint borrowAmount) public {
        vm.assume(initialDeposit > 1e8);
        vm.assume(initialDeposit < initialMint);
        vm.assume(borrowAmount < initialDeposit);
        vm.assume(borrowAmount != 0);

        vm.startPrank(alice);
        IDebtTokenBase(wethDebtToken).approveDelegation(address(l), borrowAmount);
        l.leverageNative{value: initialDeposit}(borrowAmount, 1.2e18);

        assertApproxEqAbs(alice.balance, initialMint - initialDeposit, 1, "1");
        assertApproxEqAbs(IERC20(aweth).balanceOf(alice), initialDeposit + borrowAmount, 1, "2");
        assertApproxEqAbs(IERC20(wethDebtToken).balanceOf(alice), borrowAmount, 1, "3");

        assertEq(IERC20(weth).balanceOf(address(l)), 0, "4");
        assertEq(IERC20(aweth).balanceOf(address(l)), 0, "5");
        assertEq(IERC20(wethDebtToken).balanceOf(address(l)), 0, "6");
    }

    function test_deleverageERC20(uint initialDeposit, uint borrowAmount) public {
        test_leverageERC20(initialDeposit, borrowAmount);    

        vm.startPrank(alice);

        IERC20(aweth).approve(address(l), type(uint256).max);
        l.deleverageERC20(weth, 1.2e18);

        assertApproxEqAbs(IERC20(weth).balanceOf(alice), initialMint, 0.01 ether, "1");
        assertEq(IERC20(aweth).balanceOf(alice), 0, "2");
        assertEq(IERC20(wethDebtToken).balanceOf(alice), 0, "3");

        assertEq(IERC20(weth).balanceOf(address(l)), 0, "4");
        assertEq(IERC20(aweth).balanceOf(address(l)), 0, "5");
        assertEq(IERC20(wethDebtToken).balanceOf(address(l)), 0, "6");
    }

    function test_deleverageNative(uint initialDeposit, uint borrowAmount) public {
        test_leverageNative(initialDeposit, borrowAmount);

        vm.startPrank(alice);
        IERC20(aweth).approve(address(l), type(uint256).max);
        l.deleverageNative(1.2e18);

        assertApproxEqAbs(alice.balance, initialMint, 0.01 ether, "1");
        assertEq(IERC20(aweth).balanceOf(alice), 0, "2");
        assertEq(IERC20(wethDebtToken).balanceOf(alice), 0, "3");

        assertEq(IERC20(weth).balanceOf(address(l)), 0, "4");
        assertEq(IERC20(aweth).balanceOf(address(l)), 0, "5");
        assertEq(IERC20(wethDebtToken).balanceOf(address(l)), 0, "6");
    }

    function testFail_leverageERC20InvalidHF() public {
        uint initialDeposit = 2 ether;
        uint borrowAmount = 1 ether;

        vm.startPrank(alice);
        IERC20(weth).approve(address(l), initialDeposit);
        IDebtTokenBase(wethDebtToken).approveDelegation(address(l), borrowAmount);
        l.leverageERC20(weth, initialDeposit, borrowAmount, 4e18);

        assertEq(IERC20(weth).balanceOf(alice), initialMint, "1");
        assertEq(IERC20(aweth).balanceOf(alice), 0, "2");
        assertEq(IERC20(wethDebtToken).balanceOf(alice), 0, "3");

        assertEq(IERC20(weth).balanceOf(address(l)), 0, "4");
        assertEq(IERC20(aweth).balanceOf(address(l)), 0, "5");
        assertEq(IERC20(wethDebtToken).balanceOf(address(l)), 0, "6");
    }

    // function invariant_LeverageContractBalanceMustRemainZero() 
}