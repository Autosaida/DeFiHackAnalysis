// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./dependencies.sol";

contract MicDao is ERC20,Ownable {
    using SafeMath for uint256;
    mapping(address => bool) public pairList;
    mapping(address => bool) public isDelivers;

    constructor() ERC20('MicDao', 'MicDao') {
        _mint(msg.sender, 1000 * 1e4 * 1e18);
        isDelivers[msg.sender] = true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override {
        if(pairList[recipient] && !isDelivers[sender]){
            uint256 toBurn = amount.mul(45).div(100);
            super._transfer(sender, address(1), toBurn);
            amount = amount.sub(toBurn);
        }
        super._transfer(sender, recipient, amount);
    }

    function setPairList(address[] memory addrs, bool flag) public onlyOwner {
        for (uint i = 0; i < addrs.length; i++) {
            pairList[addrs[i]] = flag;
        }
    }

    function setDelivers(address[] memory addrs, bool flag) public onlyOwner {
        for(uint i=0;i<addrs.length;i++){
            isDelivers[addrs[i]] = flag;
        }
    }
}