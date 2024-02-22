// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "./interface.sol";

interface Interface {}

contract DeFiAttacker is Test {
    // variables

    function setUp() public {
        vm.createSelectFork("eth");
        // initialize, such as vm.label()
    }

    function testExploit() external {
        uint256 attackBlockNumber = 1234;
        vm.rollFork(attackBlockNumber);

        // start attack
        // emit log
    }

    function testOther() external {}

    function helper() internal {}
}
