// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;
import "./IERC20.sol";

interface IReflection is IERC20 {
    function owner() external view returns (address);

    function reflect(uint256 amount) external;
    function deliver(uint256 amount) external;

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) external returns(uint256);
    function tokenFromReflection(uint256 rAmount) external view returns(uint256);
    
    function isExcluded(address account) external view returns (bool);
    function excludeAccount(address account) external;
}