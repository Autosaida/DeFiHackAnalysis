// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.2 <0.9.0;

interface IDVM {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDPP {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDPPAdvanced {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDPPOracle {
    function flashLoan(uint256 baseAmount, uint256 quoteAmount, address assetTo, bytes calldata data) external;
}

interface IDODOCallee {
    function DVMSellShareCall(
        address sender,
        uint256 burnShareAmount,
        uint256 baseAmount,
        uint256 quoteAmount,
        bytes calldata data
    ) external;

    function DVMFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external;

    function DPPFlashLoanCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external;

    function CPCancelCall(address sender, uint256 amount, bytes calldata data) external;

    function CPClaimBidCall(address sender, uint256 baseAmount, uint256 quoteAmount, bytes calldata data) external;
}
