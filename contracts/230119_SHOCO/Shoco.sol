// $SHOCO - ShibaChocolate
// Telegram: https://t.me/ShibaChocolate
// Fair Launch, no Dev Tokens. 100% LP.
// Snipers will be nuked.

// LP Lock immediately on launch.
// Ownership will be renounced 30 minutes after launch.

// Slippage Recommended: 9-12%
// No supply limit: 60s cooldown between transfers.

/**
 *                   ▄              ▄
 *                  ▌▒█           ▄▀▒▌
 *                  ▌▒▒█        ▄▀▒▒▒▐
 *                 ▐▄▀▒▒▀▀▀▀▄▄▄▀▒▒▒▒▒▐
 *               ▄▄▀▒░▒▒▒▒▒▒▒▒▒█▒▒▄█▒▐
 *             ▄▀▒▒▒░░░▒▒▒░░░▒▒▒▀██▀▒▌
 *            ▐▒▒▒▄▄▒▒▒▒░░░▒▒▒▒▒▒▒▀▄▒▒▌
 *            ▌░░▌█▀▒▒▒▒▒▄▀█▄▒▒▒▒▒▒▒█▒▐
 *           ▐░░░▒▒▒▒▒▒▒▒▌██▀▒▒░░░▒▒▒▀▄▌
 *           ▌░▒▄██▄▒▒▒▒▒▒▒▒▒░░░░░░▒▒▒▒▌
 *          ▌▒▀▐▄█▄█▌▄░▀▒▒░░░░░░░░░░▒▒▒▐
 *          ▐▒▒▐▀▐▀▒░▄▄▒▄▒▒▒▒▒▒░▒░▒░▒▒▒▒▌
 *          ▐▒▒▒▀▀▄▄▒▒▒▄▒▒▒▒▒▒▒▒░▒░▒░▒▒▐
 *           ▌▒▒▒▒▒▒▀▀▀▒▒▒▒▒▒░▒░▒░▒░▒▒▒▌
 *           ▐▒▒▒▒▒▒▒▒▒▒▒▒▒▒░▒░▒░▒▒▄▒▒▐
 *            ▀▄▒▒▒▒▒▒▒▒▒▒▒░▒░▒░▒▄▒▒▒▒▌
 *              ▀▄▒▒▒▒▒▒▒▒▒▒▄▄▄▀▒▒▒▒▄▀
 *                ▀▄▄▄▄▄▄▀▀▀▒▒▒▒▒▄▄▀
 *                   ▒▒▒▒▒▒▒▒▒▒▀▀
*/
// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.6.12;
import "./dependencies.sol";

// Contract implementation
contract Shoco is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => uint256) private _lastTx;
    mapping (address => uint256) private _cooldownTradeAttempts;
    mapping (address => mapping (address => uint256)) private _allowances;

    mapping (address => bool) private _isExcludedFromFee;

    mapping (address => bool) private _isExcluded;
    address[] private _excluded;
    mapping (address => bool) private _isSniper;
    address[] private _confirmedSnipers;

    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1000000000000000000000000;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;

    string private _name = 'Shiba Chocolate | t.me/ShibaChocolate';
    string private _symbol = 'SHOCO \xF0\x9F\x8D\xAB';
    uint8 private _decimals = 9;

    uint256 private _taxFee = 1;
    uint256 private _teamDev = 0;
    uint256 private _previousTaxFee = _taxFee;
    uint256 private _previousTeamDev = _teamDev;

    address payable private _teamDevAddress;

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool inSwap = false;
    bool public swapEnabled = true;
    bool public tradingOpen = false; //once switched on, can never be switched off.
    bool public cooldownEnabled = true; //cooldown time on transactions
    bool public uniswapOnly = true; //prevents users from tx'ing to other wallets to avoid cooldowns

    uint256 public _maxTxAmount = 1000000000000000000000000;
    uint256 private _numOfTokensToExchangeForTeamDev = 5000000000000000000;
    bool _txLimitsEnabled = true;

    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapEnabledUpdated(bool enabled);

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () public {
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

        // List of publicly available front-runner & sniper bots
        _isSniper[address(0x7589319ED0fD750017159fb4E4d96C63966173C1)] = true;
        _confirmedSnipers.push(address(0x7589319ED0fD750017159fb4E4d96C63966173C1));

        _isSniper[address(0x65A67DF75CCbF57828185c7C050e34De64d859d0)] = true;
        _confirmedSnipers.push(address(0x65A67DF75CCbF57828185c7C050e34De64d859d0));

        _isSniper[address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce)] = true;
        _confirmedSnipers.push(address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce));

        _isSniper[address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce)] = true;
        _confirmedSnipers.push(address(0xE031b36b53E53a292a20c5F08fd1658CDdf74fce));

        _isSniper[address(0xe516bDeE55b0b4e9bAcaF6285130De15589B1345)] = true;
        _confirmedSnipers.push(address(0xe516bDeE55b0b4e9bAcaF6285130De15589B1345));

        _isSniper[address(0xa1ceC245c456dD1bd9F2815a6955fEf44Eb4191b)] = true;
        _confirmedSnipers.push(address(0xa1ceC245c456dD1bd9F2815a6955fEf44Eb4191b));

        _isSniper[address(0xd7d3EE77D35D0a56F91542D4905b1a2b1CD7cF95)] = true;
        _confirmedSnipers.push(address(0xd7d3EE77D35D0a56F91542D4905b1a2b1CD7cF95));

        _isSniper[address(0xFe76f05dc59fEC04184fA0245AD0C3CF9a57b964)] = true;
        _confirmedSnipers.push(address(0xFe76f05dc59fEC04184fA0245AD0C3CF9a57b964));

        _isSniper[address(0xDC81a3450817A58D00f45C86d0368290088db848)] = true;
        _confirmedSnipers.push(address(0xDC81a3450817A58D00f45C86d0368290088db848));

        _isSniper[address(0x45fD07C63e5c316540F14b2002B085aEE78E3881)] = true;
        _confirmedSnipers.push(address(0x45fD07C63e5c316540F14b2002B085aEE78E3881));

        _isSniper[address(0x27F9Adb26D532a41D97e00206114e429ad58c679)] = true;
        _confirmedSnipers.push(address(0x27F9Adb26D532a41D97e00206114e429ad58c679));

        _isSniper[address(0x9282dc5c422FA91Ff2F6fF3a0b45B7BF97CF78E7)] = true;
        _confirmedSnipers.push(address(0x9282dc5c422FA91Ff2F6fF3a0b45B7BF97CF78E7));

        _isSniper[address(0xfad95B6089c53A0D1d861eabFaadd8901b0F8533)] = true;
        _confirmedSnipers.push(address(0xfad95B6089c53A0D1d861eabFaadd8901b0F8533));

        _isSniper[address(0x1d6E8BAC6EA3730825bde4B005ed7B2B39A2932d)] = true;
        _confirmedSnipers.push(address(0x1d6E8BAC6EA3730825bde4B005ed7B2B39A2932d));

        _isSniper[address(0x000000000000084e91743124a982076C59f10084)] = true;
        _confirmedSnipers.push(address(0x000000000000084e91743124a982076C59f10084));

        _isSniper[address(0x6dA4bEa09C3aA0761b09b19837D9105a52254303)] = true;
        _confirmedSnipers.push(address(0x6dA4bEa09C3aA0761b09b19837D9105a52254303));

        _isSniper[address(0x323b7F37d382A68B0195b873aF17CeA5B67cd595)] = true;
        _confirmedSnipers.push(address(0x323b7F37d382A68B0195b873aF17CeA5B67cd595));

        _isSniper[address(0x000000005804B22091aa9830E50459A15E7C9241)] = true;
        _confirmedSnipers.push(address(0x000000005804B22091aa9830E50459A15E7C9241));

        _isSniper[address(0xA3b0e79935815730d942A444A84d4Bd14A339553)] = true;
        _confirmedSnipers.push(address(0xA3b0e79935815730d942A444A84d4Bd14A339553));

        _isSniper[address(0xf6da21E95D74767009acCB145b96897aC3630BaD)] = true;
        _confirmedSnipers.push(address(0xf6da21E95D74767009acCB145b96897aC3630BaD));

        _isSniper[address(0x0000000000007673393729D5618DC555FD13f9aA)] = true;
        _confirmedSnipers.push(address(0x0000000000007673393729D5618DC555FD13f9aA));

        _isSniper[address(0x00000000000003441d59DdE9A90BFfb1CD3fABf1)] = true;
        _confirmedSnipers.push(address(0x00000000000003441d59DdE9A90BFfb1CD3fABf1));

        _isSniper[address(0x59903993Ae67Bf48F10832E9BE28935FEE04d6F6)] = true;
        _confirmedSnipers.push(address(0x59903993Ae67Bf48F10832E9BE28935FEE04d6F6));

        _isSniper[address(0x000000917de6037d52b1F0a306eeCD208405f7cd)] = true;
        _confirmedSnipers.push(address(0x000000917de6037d52b1F0a306eeCD208405f7cd));

        _isSniper[address(0x7100e690554B1c2FD01E8648db88bE235C1E6514)] = true;
        _confirmedSnipers.push(address(0x7100e690554B1c2FD01E8648db88bE235C1E6514));

        _isSniper[address(0x72b30cDc1583224381132D379A052A6B10725415)] = true;
        _confirmedSnipers.push(address(0x72b30cDc1583224381132D379A052A6B10725415));

        _isSniper[address(0x9eDD647D7d6Eceae6bB61D7785Ef66c5055A9bEE)] = true;
        _confirmedSnipers.push(address(0x9eDD647D7d6Eceae6bB61D7785Ef66c5055A9bEE));

        _isSniper[address(0xfe9d99ef02E905127239E85A611c29ad32c31c2F)] = true;
        _confirmedSnipers.push(address(0xfe9d99ef02E905127239E85A611c29ad32c31c2F));

        _isSniper[address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b)] = true;
        _confirmedSnipers.push(address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b));

        _isSniper[address(0xc496D84215d5018f6F53E7F6f12E45c9b5e8e8A9)] = true;
        _confirmedSnipers.push(address(0xc496D84215d5018f6F53E7F6f12E45c9b5e8e8A9));

        _isSniper[address(0x59341Bc6b4f3Ace878574b05914f43309dd678c7)] = true;
        _confirmedSnipers.push(address(0x59341Bc6b4f3Ace878574b05914f43309dd678c7));

        _isSniper[address(0xe986d48EfeE9ec1B8F66CD0b0aE8e3D18F091bDF)] = true;
        _confirmedSnipers.push(address(0xe986d48EfeE9ec1B8F66CD0b0aE8e3D18F091bDF));

        _isSniper[address(0x4aEB32e16DcaC00B092596ADc6CD4955EfdEE290)] = true;
        _confirmedSnipers.push(address(0x4aEB32e16DcaC00B092596ADc6CD4955EfdEE290));

        _isSniper[address(0x136F4B5b6A306091b280E3F251fa0E21b1280Cd5)] = true;
        _confirmedSnipers.push(address(0x136F4B5b6A306091b280E3F251fa0E21b1280Cd5));

        _isSniper[address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b)] = true;
        _confirmedSnipers.push(address(0x39608b6f20704889C51C0Ae28b1FCA8F36A5239b));

        _isSniper[address(0x5B83A351500B631cc2a20a665ee17f0dC66e3dB7)] = true;
        _confirmedSnipers.push(address(0x5B83A351500B631cc2a20a665ee17f0dC66e3dB7));

        _isSniper[address(0xbCb05a3F85d34f0194C70d5914d5C4E28f11Cc02)] = true;
        _confirmedSnipers.push(address(0xbCb05a3F85d34f0194C70d5914d5C4E28f11Cc02));

        _isSniper[address(0x22246F9BCa9921Bfa9A3f8df5baBc5Bc8ee73850)] = true;
        _confirmedSnipers.push(address(0x22246F9BCa9921Bfa9A3f8df5baBc5Bc8ee73850));

        _isSniper[address(0x42d4C197036BD9984cA652303e07dD29fA6bdB37)] = true;
        _confirmedSnipers.push(address(0x42d4C197036BD9984cA652303e07dD29fA6bdB37));

        _isSniper[address(0x00000000003b3cc22aF3aE1EAc0440BcEe416B40)] = true;
        _confirmedSnipers.push(address(0x00000000003b3cc22aF3aE1EAc0440BcEe416B40));

        _isSniper[address(0x231DC6af3C66741f6Cf618884B953DF0e83C1A2A)] = true;
        _confirmedSnipers.push(address(0x231DC6af3C66741f6Cf618884B953DF0e83C1A2A));

        _isSniper[address(0xC6bF34596f74eb22e066a878848DfB9fC1CF4C65)] = true;
        _confirmedSnipers.push(address(0xC6bF34596f74eb22e066a878848DfB9fC1CF4C65));

        _isSniper[address(0x20f6fCd6B8813c4f98c0fFbD88C87c0255040Aa3)] = true;
        _confirmedSnipers.push(address(0x20f6fCd6B8813c4f98c0fFbD88C87c0255040Aa3));

        _teamDev = 8;
        _teamDevAddress = payable(0x71099527F4c5B626b3D7915B1C3E893863587551);

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function openTrading() external onlyOwner() {
        swapEnabled = true;
        cooldownEnabled = true;
        tradingOpen = true;
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
        return _isSniper[account];
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

    function RemoveSniper(address account) external onlyOwner() {
        require(account != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, 'We can not blacklist Uniswap router.');
        require(!_isSniper[account], "Account is already blacklisted");
        _isSniper[account] = true;
        _confirmedSnipers.push(account);
    }

    function amnestySniper(address account) external onlyOwner() {
        require(_isSniper[account], "Account is not blacklisted");
        for (uint256 i = 0; i < _confirmedSnipers.length; i++) {
            if (_confirmedSnipers[i] == account) {
                _confirmedSnipers[i] = _confirmedSnipers[_confirmedSnipers.length - 1];
                _isSniper[account] = false;
                _confirmedSnipers.pop();
                break;
            }
        }
    }

    function removeAllFee() private {
        if(_taxFee == 0 && _teamDev == 0) return;

        _previousTaxFee = _taxFee;
        _previousTeamDev = _teamDev;

        _taxFee = 0;
        _teamDev = 0;
    }

    function restoreAllFee() private {
        _taxFee = _previousTaxFee;
        _teamDev = _previousTeamDev;
    }

    function isExcludedFromFee(address account) public view returns(bool) {
        return _isExcludedFromFee[account];
    }

    function setMaxTxPercent(uint256 maxTxPercent) external onlyOwner() {
        _maxTxAmount = _tTotal.mul(maxTxPercent).div(
            10**2
        );
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
        require(!_isSniper[recipient], "You have no power here!");
        require(!_isSniper[msg.sender], "You have no power here!");

        if(sender != owner() && recipient != owner()) {

            if (!tradingOpen) {
                if (!(sender == address(this) || recipient == address(this)
                || sender == address(owner()) || recipient == address(owner()))) {
                    require(tradingOpen, "Trading is not enabled");
                }
            }

            if (cooldownEnabled) {
                if (block.timestamp > _lastTx[sender]) {
                    _lastTx[sender] = block.timestamp + 60 seconds;
                } else {
                    require(!cooldownEnabled, "You're on cooldown! 60s between trades!");
                }
            }

            if (uniswapOnly) {
                if (
                    sender != address(this) &&
                    recipient != address(this) &&
                    sender != address(uniswapV2Router) &&
                    recipient != address(uniswapV2Router)
                ) {
                    require(
                        _msgSender() == address(uniswapV2Router) ||
                        _msgSender() == uniswapV2Pair,
                        "ERR: Uniswap only"
                    );
                }
            }
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap?
        // also, don't get caught in a circular charity event.
        // also, don't swap if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >= _numOfTokensToExchangeForTeamDev;
        if (!inSwap && swapEnabled && overMinTokenBalance && sender != uniswapV2Pair) {
            // We need to swap the current tokens to ETH and send to the charity wallet
            swapTokensForEth(contractTokenBalance);

            uint256 contractETHBalance = address(this).balance;
            if(contractETHBalance > 0) {
                sendETHToTeamDev(address(this).balance);
            }
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]){
            takeFee = false;
        }

        //transfer amount, it will take tax and fee

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

    function sendETHToTeamDev(uint256 amount) private {
        _teamDevAddress.transfer(amount.div(2));
    }

    // We are exposing these functions to be able to manual swap and send
    // in case the token is highly valued and 5M becomes too much
    function manualSwap() external onlyOwner() {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForEth(contractBalance);
    }

    function manualSend() external onlyOwner() {
        uint256 contractETHBalance = address(this).balance;
        sendETHToTeamDev(contractETHBalance);
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
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeCharity(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeCharity(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeCharity(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee, uint256 tCharity) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeCharity(tCharity);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _takeCharity(uint256 tCharity) private {
        uint256 currentRate =  _getRate();
        uint256 rCharity = tCharity.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rCharity);
        if(_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tCharity);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee, uint256 tCharity) = _getTValues(tAmount, _taxFee, _teamDev);
        uint256 currentRate =  _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee, tCharity);
    }

    function _getTValues(uint256 tAmount, uint256 taxFee, uint256 charityFee) private pure returns (uint256, uint256, uint256) {
        uint256 tFee = tAmount.mul(taxFee).div(100);
        uint256 tCharity = tAmount.mul(charityFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tCharity);
        return (tTransferAmount, tFee, tCharity);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
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

    function _removeTxLimit() external onlyOwner() {
        _maxTxAmount = 1000000000000000000000000;
    }

    // Yes, there are here if I fucked up on the logic and need to disable them.
    function _removeDestLimit() external onlyOwner() {
        uniswapOnly = false;
    }

    function _disableCooldown() external onlyOwner() {
        cooldownEnabled = false;
    }

    function _enableCooldown() external onlyOwner() {
        cooldownEnabled = true;
    }

    function _setExtWallet(address payable teamDevAddress) external onlyOwner() {
        _teamDevAddress = teamDevAddress;
    }
}