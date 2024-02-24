/*
   
               
              /\___/\ ((
              \`@_@'/  ))
              {_:Y:.}_//
--------------{_}^-'{_}-------------------- 
 _____   ___   __  __   ___  _   _  _   _ 
|_   _| / _ \ |  \/  | |_ _|| \ | || | | | 
  | |  | | | || |\/| |  | | |  \| || | | |
  | |  | |_| || |  | |  | | | |\  || |_| |
  |_|   \___/ |_|  |_| |___||_| \_| \___/ 
                                          
https://www.tominu.xyz
https://t.me/tominutoken

--------------------------------------------

*/

// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.6.12;
import "./dependencies.sol";
    // Contract implementation
contract TomInu is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => uint256) public timestamp;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
    mapping (address => bool) private _isBlackListedBot;
    address[] private _blackListedBots;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1733820000000000000000;  //1,000,000,000,000
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    uint256 public _CoolDown = 15 seconds;

    string private _name = 'Tom Inu';
    string private _symbol = 'TINU';
    uint8 private _decimals = 9;
    
    // Tax and team fees will start at 0 so we don't have a big impact when deploying 
    uint256 private _taxFee = 0; 
    uint256 private _teamFee = 0;
    uint256 private _previousTaxFee = _taxFee;
    uint256 private _previousteamFee = _teamFee;

    address payable public _teamWalletAddress;
    address payable public _marketingWalletAddress;
    
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool inSwap = false;
    bool public swapEnabled = true;
    bool public tradingEnabled = false;
    bool public cooldownEnabled = true;

    uint256 public _maxTxAmount = _tTotal; 
    //no max tx limit at deploy
    uint256 private _numOfTokensToExchangeForteam = 5000000000000000;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapEnabledUpdated(bool enabled);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor (address payable teamWalletAddress, address payable marketingWalletAddress) public {
        _teamWalletAddress = teamWalletAddress;
        _marketingWalletAddress = marketingWalletAddress;
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // UniswapV2 for Ethereum network
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        // Exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        
        _isBlackListedBot[address(0x7589319ED0fD750017159fb4E4d96C63966173C1)] = true;
        _blackListedBots.push(address(0x7589319ED0fD750017159fb4E4d96C63966173C1));
        
        _isBlackListedBot[address(0x65A67DF75CCbF57828185c7C050e34De64d859d0)] = true;
        _blackListedBots.push(address(0x65A67DF75CCbF57828185c7C050e34De64d859d0));
        
        _isBlackListedBot[address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce)] = true;
        _blackListedBots.push(address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce));
        
        _isBlackListedBot[address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce)] = true;
        _blackListedBots.push(address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce));

        _isBlackListedBot[address(0xe516bDeE55b0b4e9bAcaF6285130De15589B1345)] = true;
        _blackListedBots.push(address(0xe516bDeE55b0b4e9bAcaF6285130De15589B1345));

        _isBlackListedBot[address(0xa1ceC245c456dD1bd9F2815a6955fEf44Eb4191b)] = true;
        _blackListedBots.push(address(0xa1ceC245c456dD1bd9F2815a6955fEf44Eb4191b));

        _isBlackListedBot[address(0xd7d3EE77D35D0a56F91542D4905b1a2b1CD7cF95)] = true;
        _blackListedBots.push(address(0xd7d3EE77D35D0a56F91542D4905b1a2b1CD7cF95));

        _isBlackListedBot[address(0xFe76f05dc59fEC04184fA0245AD0C3CF9a57b964)] = true;
        _blackListedBots.push(address(0xFe76f05dc59fEC04184fA0245AD0C3CF9a57b964));

        _isBlackListedBot[address(0xDC81a3450817A58D00f45C86d0368290088db848)] = true;
        _blackListedBots.push(address(0xDC81a3450817A58D00f45C86d0368290088db848));

        _isBlackListedBot[address(0x45fD07C63e5c316540F14b2002B085aEE78E3881)] = true;
        _blackListedBots.push(address(0x45fD07C63e5c316540F14b2002B085aEE78E3881));

        _isBlackListedBot[address(0x27F9Adb26D532a41D97e00206114e429ad58c679)] = true;
        _blackListedBots.push(address(0x27F9Adb26D532a41D97e00206114e429ad58c679));
        
        _isBlackListedBot[address(0x9282dc5c422FA91Ff2F6fF3a0b45B7BF97CF78E7)] = true;
        _blackListedBots.push(address(0x9282dc5c422FA91Ff2F6fF3a0b45B7BF97CF78E7));
        
        _isBlackListedBot[address(0xfad95B6089c53A0D1d861eabFaadd8901b0F8533)] = true;
        _blackListedBots.push(address(0xfad95B6089c53A0D1d861eabFaadd8901b0F8533));
        
        _isBlackListedBot[address(0x1d6E8BAC6EA3730825bde4B005ed7B2B39A2932d)] = true;
        _blackListedBots.push(address(0x1d6E8BAC6EA3730825bde4B005ed7B2B39A2932d));
        
        _isBlackListedBot[address(0x000000000000084e91743124a982076C59f10084)] = true;
        _blackListedBots.push(address(0x000000000000084e91743124a982076C59f10084));

        _isBlackListedBot[address(0x6dA4bEa09C3aA0761b09b19837D9105a52254303)] = true;
        _blackListedBots.push(address(0x6dA4bEa09C3aA0761b09b19837D9105a52254303));
        
        _isBlackListedBot[address(0x323b7F37d382A68B0195b873aF17CeA5B67cd595)] = true;
        _blackListedBots.push(address(0x323b7F37d382A68B0195b873aF17CeA5B67cd595));
        
        _isBlackListedBot[address(0x000000005804B22091aa9830E50459A15E7C9241)] = true;
        _blackListedBots.push(address(0x000000005804B22091aa9830E50459A15E7C9241));
        
        _isBlackListedBot[address(0xA3b0e79935815730d942A444A84d4Bd14A339553)] = true;
        _blackListedBots.push(address(0xA3b0e79935815730d942A444A84d4Bd14A339553));
        
        _isBlackListedBot[address(0xf6da21E95D74767009acCB145b96897aC3630BaD)] = true;
        _blackListedBots.push(address(0xf6da21E95D74767009acCB145b96897aC3630BaD));
        
        _isBlackListedBot[address(0x0000000000007673393729D5618DC555FD13f9aA)] = true;
        _blackListedBots.push(address(0x0000000000007673393729D5618DC555FD13f9aA));
        
        _isBlackListedBot[address(0x00000000000003441d59DdE9A90BFfb1CD3fABf1)] = true;
        _blackListedBots.push(address(0x00000000000003441d59DdE9A90BFfb1CD3fABf1));
        
        _isBlackListedBot[address(0x59903993Ae67Bf48F10832E9BE28935FEE04d6F6)] = true;
        _blackListedBots.push(address(0x59903993Ae67Bf48F10832E9BE28935FEE04d6F6));
        
        _isBlackListedBot[address(0x000000917de6037d52b1F0a306eeCD208405f7cd)] = true;
        _blackListedBots.push(address(0x000000917de6037d52b1F0a306eeCD208405f7cd));
        
        _isBlackListedBot[address(0x7100e690554B1c2FD01E8648db88bE235C1E6514)] = true;
        _blackListedBots.push(address(0x7100e690554B1c2FD01E8648db88bE235C1E6514));
        
        _isBlackListedBot[address(0x72b30cDc1583224381132D379A052A6B10725415)] = true;
        _blackListedBots.push(address(0x72b30cDc1583224381132D379A052A6B10725415));
        
        _isBlackListedBot[address(0x9eDD647D7d6Eceae6bB61D7785Ef66c5055A9bEE)] = true;
        _blackListedBots.push(address(0x9eDD647D7d6Eceae6bB61D7785Ef66c5055A9bEE));

        _isBlackListedBot[address(0xfe9d99ef02E905127239E85A611c29ad32c31c2F)] = true;
        _blackListedBots.push(address(0xfe9d99ef02E905127239E85A611c29ad32c31c2F));
        
        _isBlackListedBot[address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b)] = true;
        _blackListedBots.push(address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b));
        
        _isBlackListedBot[address(0xc496D84215d5018f6F53E7F6f12E45c9b5e8e8A9)] = true;
        _blackListedBots.push(address(0xc496D84215d5018f6F53E7F6f12E45c9b5e8e8A9));

        _isBlackListedBot[address(0x59341Bc6b4f3Ace878574b05914f43309dd678c7)] = true;
        _blackListedBots.push(address(0x59341Bc6b4f3Ace878574b05914f43309dd678c7));

        _isBlackListedBot[address(0xe986d48EfeE9ec1B8F66CD0b0aE8e3D18F091bDF)] = true;
        _blackListedBots.push(address(0xe986d48EfeE9ec1B8F66CD0b0aE8e3D18F091bDF));

        _isBlackListedBot[address(0x4aEB32e16DcaC00B092596ADc6CD4955EfdEE290)] = true;
        _blackListedBots.push(address(0x4aEB32e16DcaC00B092596ADc6CD4955EfdEE290));
        
        _isBlackListedBot[address(0x136F4B5b6A306091b280E3F251fa0E21b1280Cd5)] = true;
        _blackListedBots.push(address(0x136F4B5b6A306091b280E3F251fa0E21b1280Cd5));
        
        _isBlackListedBot[address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b)] = true;
        _blackListedBots.push(address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b));
        
        _isBlackListedBot[address(0x5B83A351500B631cc2a20a665ee17f0dC66e3dB7)] = true;
        _blackListedBots.push(address(0x5B83A351500B631cc2a20a665ee17f0dC66e3dB7));
        
        
        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }
    
    function isBlackListed(address account) public view returns (bool) {
        return _isBlackListedBot[account];
    }

    function setExcludeFromFee(address account, bool excluded) external onlyOwner() {
        _isExcludedFromFee[account] = excluded;
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    function excludeAccount(address account) external onlyOwner() {
        require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not exclude Uniswap router.');
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }
    
    function addBotToBlackList(address account) external onlyOwner() {
        require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not blacklist Uniswap router.');
        require(!_isBlackListedBot[account], "Account is already blacklisted");
        _isBlackListedBot[account] = true;
        _blackListedBots.push(account);
    }

    function removeBotFromBlackList(address account) external onlyOwner() {
        require(_isBlackListedBot[account], "Account is not blacklisted");
        for (uint256 i = 0; i < _blackListedBots.length; i++) {
            if (_blackListedBots[i] == account) {
                _blackListedBots[i] = _blackListedBots[_blackListedBots.length - 1];
                _isBlackListedBot[account] = false;
                _blackListedBots.pop();
                break;
            }
        }
    }

    function removeAllFee() private {
        if(_taxFee == 0 && _teamFee == 0) return;
        
        _previousTaxFee = _taxFee;
        _previousteamFee = _teamFee;
        
        _taxFee = 0;
        _teamFee = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _teamFee = _previousteamFee;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }
    
    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(10**2);
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!_isBlackListedBot[recipient], "You have no power here!");
        require(!_isBlackListedBot[sender], "You have no power here!");
        
        if(sender != owner() && recipient != owner()) {  
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        
            //you can't trade this on a dex until trading enabled
            if (sender == uniswapV2Pair || recipient == uniswapV2Pair) { require(tradingEnabled, "Trading is not enabled yet");}

        }
        
        //cooldown logic starts
        
        if(cooldownEnabled) {
        //perform all cooldown checks below only if enabled
            if (sender == uniswapV2Pair ) {
            //they just bought add cooldown    
                if (!_isExcluded[recipient]) { 
                    timestamp[recipient] = block.timestamp.add(_CoolDown); 
                }
            }
            
            // exclude owner and uniswap
            if(sender != owner() && sender != uniswapV2Pair) {
            // dont apply cooldown to other excluded addresses
                if (!_isExcluded[sender]) {
                    require(block.timestamp >= timestamp[sender], "Cooldown"); 
                }
            }
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap?
        // also, don't get caught in a circular team event.
        // also, don't swap if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));
        
        if(contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }
        
        bool overMinTokenBalance = contractTokenBalance >= _numOfTokensToExchangeForteam;
        if (!inSwap && swapEnabled && overMinTokenBalance && sender != uniswapV2Pair) {
            // We need to swap the current tokens to ETH and send to the team wallet
            swapTokensForEth(contractTokenBalance);
            uint256 contractETHBalance = address(this).balance;
            if(contractETHBalance > 0) {
                sendETHToteam(address(this).balance);
            }
        }
        
        //indicates if fee should be deducted from transfer
        bool takeFee = true;
        
        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            takeFee = false;
        }
        
        //transfer amount, it will take tax and team fee
        _tokenTransfer(sender,recipient,amount,takeFee);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap{
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
    
    function sendETHToteam(uint256 amount) private {
        _teamWalletAddress.transfer(amount.div(2));
        _marketingWalletAddress.transfer(amount.div(2));
    }
    
    // We are exposing these functions to be able to manual swap and send
    // in case the token is highly valued and 5M becomes too much
    function manualSwap() external onlyOwner() {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }
    
    function manualSend() external onlyOwner() {
        uint256 contractETHBalance = address(this).balance;
        sendETHToteam(contractETHBalance);
    }

    function setSwapEnabled(bool enabled) external onlyOwner(){
        swapEnabled = enabled;
    }
    
    function _tokenTransfer(address sender, address recipient, uint256 amount, bool takeFee) private {
        if(!takeFee)
            removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }

        if(!takeFee)
            restoreAllFee();
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tteam) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount); 
        _taketeam(tteam); 
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tteam) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);    
        _taketeam(tteam);           
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tteam) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount); 
        _taketeam(tteam);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tteam) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);   
        _taketeam(tteam);         
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _taketeam(uint256 tteam) private {
        uint256 currentRate =  _getRate();
        uint256 rteam = tteam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rteam);
        // come out of thin air
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tteam);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

        //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tteam) = _getTValues(tAmount, _taxFee, _teamFee);
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tteam);
    }

    function _getTValues(uint256 tAmount, uint256 taxFee, uint256 teamFee) private pure returns (uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(taxFee).div(100);
        uint256 tteam = tAmount.mul(teamFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tteam);
        return (tTransferAmount, tFee, tteam);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
        // Missing sub teamFee
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }
    
    function _getTaxFee() private view returns(uint256) {
        return _taxFee;
    }

    function _getMaxTxAmount() private view returns(uint256) {
        return _maxTxAmount;
    }

    function _getETHBalance() public view returns(uint256 balance) {
        return address(this).balance;
    }
    
    function _setTaxFee(uint256 taxFee) external onlyOwner() {
        require(taxFee >= 1 && taxFee <= 10, 'taxFee should be in 1 - 10');
        _taxFee = taxFee;
    }

    function _setteamFee(uint256 teamFee) external onlyOwner() {
        require(teamFee >= 1 && teamFee <= 11, 'teamFee should be in 1 - 11');
        _teamFee = teamFee;
    }
    
    function _setteamWallet(address payable teamWalletAddress) external onlyOwner() {
        _teamWalletAddress = teamWalletAddress;
    }
    
    function _setmarketingWallet(address payable marketingWalletAddress) external onlyOwner() {
        _marketingWalletAddress = marketingWalletAddress;
    }

    function LetTradingBegin(bool _tradingEnabled) external onlyOwner() {
        tradingEnabled = _tradingEnabled;
    }
    
    function ToggleCoolDown(bool _cooldownEnabled) external onlyOwner() {
        cooldownEnabled = _cooldownEnabled;
    }
    
    function setCoolDown(uint256 CoolDown) external onlyOwner() {
        _CoolDown = (CoolDown * 1 seconds);
    }    
    
}