/*
                                                             ,---,  
         ,---._                          ____  ,-.----.   ,`--.' |  
       .-- -.' \                       ,'  , `.\    /  \  |   :  :  
       |    |   :         ,--,      ,-+-,.' _ ||   :    \ '   '  ;  
       :    ;   |       ,'_ /|   ,-+-. ;   , |||   |  .\ :|   |  |  
       :        |  .--. |  | :  ,--.'|'   |  ;|.   :  |: |'   :  ;  
       |    :   :,'_ /| :  . | |   |  ,', |  ':|   |   \ :|   |  '  
       :         |  ' | |  . . |   | /  | |  |||   : .   /'   :  |  
       |    ;   ||  | ' |  | | '   | :  | :  |,;   | |`-' ;   |  ;  
   ___ l         :  | | :  ' ; ;   . |  ; |--' |   | ;    `---'. |  
 /    /\    J   :|  ; ' |  | ' |   : |  | ,    :   ' |     `--..`;  
/  ../  `..-    ,:  | : ;  ; | |   : '  |/     :   : :    .--,_     
\    \         ; '  :  `--'   \;   | |`-'      |   | :    |    |`.  
 \    \      ,'  :  ,      .-./|   ;/          `---'.|    `-- -`, ; 
  "---....--'     `--`----'    '---'             `---`      '---`"  
                                                                    

(Website) https://jump.farm
(Telegram) https://t.me/jumpportal
(Twitter) https://twitter.com/jumpfarm

*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
pragma experimental ABIEncoderV2;

import "./dependencies.sol";

contract Token is ERC20, Ownable {
    /// STATE VARIABLES ///

    /// @notice Address of UniswapV2Router
    IUniswapV2Router02 public immutable uniswapV2Router;
    /// @notice Address of /ETH LP
    address public immutable uniswapV2Pair;
    /// @notice Burn address
    address public constant deadAddress = address(0xdead);
    /// @notice WETH address
    address public immutable WETH;
    /// @notice  treasury
    address public treasury;
    /// @notice Team wallet address
    address public teamWallet;

    bool private swapping;

    /// @notice Bool if trading is active
    bool public tradingActive = true;
    /// @notice Bool if swap is enabled
    bool public swapEnabled = true;
    /// @notice Bool if limits are in effect
    bool public limitsInEffect = true;

    /// @notice Current max wallet amount (If limits in effect)
    uint256 public maxWallet;
    /// @notice Current max transaction amount (If limits in effect)
    uint256 public maxTransactionAmount;
    /// @notice Current percent of supply to swap tokens at (i.e. 5 = 0.05%)
    uint256 public swapPercent;

    /// @notice Current buy side total fees
    uint256 public buyTotalFees;
    /// @notice Current buy side backing fee
    uint256 public buyBackingFee;
    /// @notice Current buy side liquidity fee
    uint256 public buyLiquidityFee;
    /// @notice Current buy side team fee
    uint256 public buyTeamFee;

    /// @notice Current sell side total fees
    uint256 public sellTotalFees;
    /// @notice Current sell side backing fee
    uint256 public sellBackingFee;
    /// @notice Current sell side liquidity fee
    uint256 public sellLiquidityFee;
    /// @notice Current sell side team fee
    uint256 public sellTeamFee;

    /// @notice Current tokens going for backing
    uint256 public tokensForBacking;
    /// @notice Current tokens going for liquidity
    uint256 public tokensForLiquidity;
    /// @notice Current tokens going for tean
    uint256 public tokensForTeam;

    /// MAPPINGS ///

    /// @dev Bool if address is excluded from fees
    mapping(address => bool) private _isExcludedFromFees;

    /// @notice Bool if address is excluded from max transaction amount
    mapping(address => bool) public _isExcludedMaxTransactionAmount;

    /// @notice Bool if address is AMM pair
    mapping(address => bool) public automatedMarketMakerPairs;

    /// EVENTS ///

    event ExcludeFromFees(address indexed account, bool isExcluded);

    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event teamWalletUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );

    /// CONSTRUCTOR ///

    /// @param _weth  Address of WETH
    constructor(address _weth) ERC20("JUMP Token", "JUMP") {
        WETH = _weth;
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );

        uint256 startingSupply_ = 1_000_000 * 10 ** 9;

        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        _setAutomatedMarketMakerPair(address(uniswapV2Pair), true);

        uint256 _buyBackingFee = 1;
        uint256 _buyLiquidityFee = 0;
        uint256 _buyTeamFee = 2;

        uint256 _sellBackingFee = 1;
        uint256 _sellLiquidityFee = 0;
        uint256 _sellTeamFee = 2;

        maxWallet = 10_000 * 1e9; // 1%
        maxTransactionAmount = 10_000 * 1e9; // 1%
        swapPercent = 25; // 0.25%

        buyBackingFee = _buyBackingFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyTeamFee = _buyTeamFee;
        buyTotalFees = buyBackingFee + buyLiquidityFee + buyTeamFee;

        sellBackingFee = _sellBackingFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellTeamFee = _sellTeamFee;
        sellTotalFees = sellBackingFee + sellLiquidityFee + sellTeamFee;

        teamWallet = owner(); // set as team wallet

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);

        excludeFromMaxTransaction(owner(), true);
        excludeFromMaxTransaction(address(this), true);
        excludeFromMaxTransaction(address(0xdead), true);

        _mint(msg.sender, startingSupply_);
    }

    receive() external payable {}

    /// AMM PAIR ///

    /// @notice       Sets if address is AMM pair
    /// @param pair   Address of pair
    /// @param value  Bool if AMM pair
    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        require(
            pair != uniswapV2Pair,
            "The pair cannot be removed from automatedMarketMakerPairs"
        );

        _setAutomatedMarketMakerPair(pair, value);
    }

    /// @dev Internal function to set `vlaue` of `pair`
    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;

        emit SetAutomatedMarketMakerPair(pair, value);
    }

    /// INTERNAL TRANSFER ///

    /// @dev Internal function to burn `amount` from `account`
    function _burnFrom(address account, uint256 amount) internal {
        uint256 decreasedAllowance_ = allowance(account, msg.sender) - amount;

        _approve(account, msg.sender, decreasedAllowance_);
        _burn(account, amount);
    }

    /// @dev Internal function to transfer - handles fee logic
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (limitsInEffect) {
            if (
                from != owner() &&
                to != owner() &&
                to != address(0) &&
                to != address(0xdead) &&
                !swapping
            ) {
                if (!tradingActive) {
                    require(
                        _isExcludedFromFees[from] || _isExcludedFromFees[to],
                        "Trading is not active."
                    );
                }

                //when buy
                if (
                    automatedMarketMakerPairs[from] &&
                    !_isExcludedMaxTransactionAmount[to]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Buy transfer amount exceeds the maxTransactionAmount."
                    );
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "Max wallet exceeded"
                    );
                }
                //when sell
                else if (
                    automatedMarketMakerPairs[to] &&
                    !_isExcludedMaxTransactionAmount[from]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Sell transfer amount exceeds the maxTransactionAmount."
                    );
                } else if (!_isExcludedMaxTransactionAmount[to]) {
                    require(
                        amount + balanceOf(to) <= maxWallet,
                        "Max wallet exceeded"
                    );
                }
            }
        }

        uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount();

        if (
            canSwap &&
            swapEnabled &&
            !swapping &&
            !automatedMarketMakerPairs[from] &&
            !_isExcludedFromFees[from] &&
            !_isExcludedFromFees[to]
        ) {
            swapping = true;

            swapBack();

            swapping = false;
        }

        bool takeFee = !swapping;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        // only take fees on buys/sells, do not take on wallet transfers
        if (takeFee) {
            // on sell
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = (amount * sellTotalFees) / 100;
                tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
                tokensForTeam += (fees * sellTeamFee) / sellTotalFees;
                tokensForBacking += (fees * sellBackingFee) / sellTotalFees;
            }
            // on buy
            else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / 100;
                tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
                tokensForTeam += (fees * buyTeamFee) / buyTotalFees;
                tokensForBacking += (fees * buyBackingFee) / buyTotalFees;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    /// INTERNAL FUNCTION ///

    /// @dev INTERNAL function to swap `tokenAmount` for ETH
    /// @dev Invoked in `swapBack()`
    function swapTokensForEth(uint256 tokenAmount) internal {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    /// @dev INTERNAL function to add `tokenAmount` and `ethAmount` to LP
    /// @dev Invoked in `swapBack()`
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) internal {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            treasury,
            block.timestamp
        );
    }

    /// @dev INTERNAL function to transfer fees properly
    /// @dev Invoked in `_transfer()`
    function swapBack() internal {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForLiquidity +
            tokensForBacking +
            tokensForTeam;
        bool success;

        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }

        if (contractBalance > swapTokensAtAmount() * 20) {
            contractBalance = swapTokensAtAmount() * 20;
        }

        // Halve the amount of liquidity tokens
        uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
            totalTokensToSwap /
            2;
        uint256 amountToSwapForETH = contractBalance - liquidityTokens;

        uint256 initialETHBalance = address(this).balance;

        swapTokensForEth(amountToSwapForETH);

        uint256 ethBalance = address(this).balance - initialETHBalance;

        uint256 ethForBacking = (ethBalance * tokensForBacking) /
            totalTokensToSwap -
            (tokensForLiquidity / 2);

        uint256 ethForTeam = (ethBalance * tokensForTeam) /
            totalTokensToSwap -
            (tokensForLiquidity / 2);

        uint256 ethForLiquidity = ethBalance - ethForBacking - ethForTeam;

        tokensForLiquidity = 0;
        tokensForBacking = 0;
        tokensForTeam = 0;

        (success, ) = address(teamWallet).call{value: ethForTeam}("");

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                tokensForLiquidity
            );
        }

        uint256 _balance = address(this).balance;
        IWETH(WETH).deposit{value: _balance}();
        IERC20(WETH).transfer(treasury, _balance);
    }

    /// VIEW FUNCTION ///

    /// @notice Returns decimals
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    /// @notice Returns if address is excluded from fees
    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    /// @notice Returns at what percent of supply to swap tokens at
    function swapTokensAtAmount() public view returns (uint256 amount_) {
        amount_ = (totalSupply() * swapPercent) / 10000;
    }

    /// TREASURY FUNCTION ///

    /// @notice         Mint (Only by treasury)
    /// @param account  Address to mint to
    /// @param amount   Amount to mint
    function mint(address account, uint256 amount) external {
        require(msg.sender == treasury, "msg.sender not treasury");
        _mint(account, amount);
    }

    /// USER FUNCTIONS ///

    /// @notice         Burn
    /// @param account  Address to burn from
    /// @param amount   Amount to to burn
    function burnFrom(address account, uint256 amount) external {
        _burnFrom(account, amount);
    }

    /// @notice         Burn
    /// @param amount   Amount to to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /// OWNER FUNCTIONS ///

    /// @notice Set address of treasury
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        excludeFromFees(_treasury, true);
        excludeFromMaxTransaction(_treasury, true);
    }

    /// @notice Enable trading - once enabled, can never be turned off
    function enableTrading() external onlyOwner {
        tradingActive = true;
        swapEnabled = true;
    }

    /// @notice Update percent of supply to swap tokens at
    function updateSwapTokensAtPercent(
        uint256 newPercent
    ) external onlyOwner returns (bool) {
        require(
            newPercent >= 1,
            "Swap amount cannot be lower than 0.01% total supply."
        );
        require(
            newPercent <= 50,
            "Swap amount cannot be higher than 0.50% total supply."
        );
        swapPercent = newPercent;
        return true;
    }

    /// @notice Update swap enabled
    /// @dev    Only use to disable contract sales if absolutely necessary (emergency use only)
    function updateSwapEnabled(bool enabled) external onlyOwner {
        swapEnabled = enabled;
    }

    /// @notice Update buy side fees
    function updateBuyFees(
        uint256 _backingFee,
        uint256 _liquidityFee,
        uint256 _teamFee
    ) external onlyOwner {
        buyBackingFee = _backingFee;
        buyLiquidityFee = _liquidityFee;
        buyTeamFee = _teamFee;
        buyTotalFees = buyBackingFee + buyLiquidityFee + buyTeamFee;
    }

    /// @notice Update sell side fees
    function updateSellFees(
        uint256 _backingFee,
        uint256 _liquidityFee,
        uint256 _teamFee
    ) external onlyOwner {
        sellBackingFee = _backingFee;
        sellLiquidityFee = _liquidityFee;
        sellTeamFee = _teamFee;
        sellTotalFees = sellBackingFee + sellLiquidityFee + sellTeamFee;
    }

    /// @notice Set if an address is excluded from fees
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    /// @notice Set if an address is excluded from max transaction
    function excludeFromMaxTransaction(
        address updAds,
        bool isEx
    ) public onlyOwner {
        _isExcludedMaxTransactionAmount[updAds] = isEx;
    }

    /// @notice Update team wallet
    function updateTeamWallet(address newWallet) external onlyOwner {
        emit teamWalletUpdated(newWallet, teamWallet);
        teamWallet = newWallet;
        excludeFromFees(newWallet, true);
        excludeFromMaxTransaction(newWallet, true);
    }

    /// @notice Remove limits in palce
    function removeLimits() external onlyOwner returns (bool) {
        limitsInEffect = false;
        return true;
    }

    /// @notice Withdraw stuck tokens from contract
    function withdrawStuck() external onlyOwner {
        uint256 balance = IERC20(address(this)).balanceOf(address(this));
        IERC20(address(this)).transfer(msg.sender, balance);
        payable(msg.sender).transfer(address(this).balance);
    }

    /// @notice Withdraw stuck token from contract
    function withdrawStuckToken(
        address _token,
        address _to
    ) external onlyOwner {
        require(_token != address(0), "_token address cannot be 0");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(_to, _contractBalance);
    }

    /// @notice Withdraw stuck ETH from contract
    function withdrawStuckEth(address toAddr) external onlyOwner {
        (bool success, ) = toAddr.call{value: address(this).balance}("");
        require(success);
    }
}
