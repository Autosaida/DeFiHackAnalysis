// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./dependencies.sol";

contract MinterProxyV2 is Controller, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using Address for address payable;

    address public immutable NATIVE =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public wNATIVE;

    uint256 MAX_UINT256 =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    mapping(uint256 => bool) public completedOrder;

    address public _liquidpool;

    uint256 public _orderID;

    bool private _paused;

    event Paused(address account);

    event Unpaused(address account);

    event LogVaultIn(
        address indexed token,
        uint256 indexed orderID,
        address indexed receiver,
        uint256 amount,
        uint256 serviceFee,
        uint256 gasFee
    );
    event LogVaultOut(
        address indexed token,
        address indexed from,
        uint256 indexed orderID,
        uint256 amount,
        address vault,
        bytes order
    );

    event LogVaultCall(
        address indexed target,
        uint256 amount,
        bool success,
        bytes reason
    );

    constructor(uint256 _id_prefix, address _lp, address _wNative) {
        _liquidpool = _lp;
        _paused = false;
        _orderID = _id_prefix * (10 ** 9);
        wNATIVE = _wNative;
    }

    receive() external payable {}

    fallback() external payable {}

    modifier whenNotPaused() {
        require(!_paused, "MP: paused");
        _;
    }

    function chainID() public view returns (uint) {
        return block.chainid;
    }

    function setLiquidpool(address _lp) external onlyOwner {
        _liquidpool = _lp;
    }

    function setWrapNative(address _wNative) external onlyOwner {
        wNATIVE = _wNative;
    }

    function needWrapNative() internal view returns (bool) {
        return wNATIVE != address(0);
    }

    function liquidpool() internal view returns (address) {
        if (_liquidpool != address(0)) {
            return _liquidpool;
        }
        return address(this);
    }

    function pause() external onlyOwner {
        _paused = true;
        emit Paused(_msgSender());
    }

    function unpause() external onlyOwner {
        _paused = false;
        emit Unpaused(_msgSender());
    }

    function isUUIDCompleted(uint256 uuid) external view returns (bool) {
        return completedOrder[uuid];
    }

    function _registerOrder(uint256 uuid) internal {
        require(!completedOrder[uuid], "MP: already completed");
        completedOrder[uuid] = true;
    }

    function _balanceOf(address receiveToken) internal view returns (uint256) {
        uint256 _balance;
        if (receiveToken == NATIVE) {
            if (needWrapNative()) {
                _balance = IERC20(wNATIVE).balanceOf(liquidpool());
            } else {
                _balance = address(this).balance;
            }
        } else {
            _balance = IERC20(receiveToken).balanceOf(liquidpool());
        }
        return _balance;
    }

    function _balanceOfSelf(
        address receiveToken
    ) internal view returns (uint256) {
        uint256 _balance;
        if (receiveToken == NATIVE) {
            _balance = address(this).balance;
        } else {
            _balance = IERC20(receiveToken).balanceOf(address(this));
        }
        return _balance;
    }

    function _checkVaultOut(
        address tokenAddr,
        uint256 amount,
        bytes calldata order
    ) internal pure {
        require(tokenAddr != address(0), "MP: tokenAddress is invalid");
        require(amount > 0, "MP: amount is 0");
        require(order.length > 0, "MP: order is empty");
    }

    function vaultOut(
        address tokenAddr,
        uint256 amount,
        bool burnable,
        bytes calldata order
    ) external payable nonReentrant whenNotPaused {
        _checkVaultOut(tokenAddr, amount, order);

        if (tokenAddr == NATIVE) {
            require(amount == msg.value, "MP: amount is invalid");
            if (needWrapNative()) {
                uint256 old = IERC20(wNATIVE).balanceOf(address(this));
                IWrapToken(wNATIVE).deposit{value: msg.value}();
                uint256 val = IERC20(wNATIVE).balanceOf(address(this));
                require(val - old == amount, "MP: warp token dismatch");
                IERC20(wNATIVE).safeTransfer(_liquidpool, amount);
            } else {
                TransferHelper.safeTransferNative(_liquidpool, amount);
            }
        } else if (burnable) {
            uint256 old = IERC20(tokenAddr).balanceOf(_msgSender());
            IMintBurnToken(tokenAddr).burn(_msgSender(), amount);
            uint256 val = IERC20(tokenAddr).balanceOf(_msgSender());
            require(val == old - amount, "MP: burn failed");
        } else {
            IERC20(tokenAddr).safeTransferFrom(
                _msgSender(),
                liquidpool(),
                amount
            );
        }

        _orderID++;
        emit LogVaultOut(
            tokenAddr,
            _msgSender(),
            _orderID,
            amount,
            burnable ? address(0) : liquidpool(),
            order
        );
    }

    function vaultIn(
        uint256 orderID,
        address receiveToken,
        address receiver,
        bool burnable,
        uint256 amount
    ) external onlyController whenNotPaused {
        require(orderID > 0, "MP: orderID empty");
        require(receiver != address(0), "MP: receiver invaild");
        require(amount > 0, "MP: amount is empty");
        if (!burnable) {
            require(
                _balanceOf(receiveToken) >= amount,
                "MP: insufficient balance"
            );
        }
        _registerOrder(orderID);
        if (receiveToken == NATIVE) {
            if (needWrapNative()) {
                IERC20(wNATIVE).safeTransferFrom(
                    liquidpool(),
                    address(this),
                    amount
                );
                uint256 old = address(this).balance;
                IWrapToken(wNATIVE).withdraw(amount);
                uint256 val = address(this).balance;
                require(
                    val - old == amount,
                    "MP: native token amount dismatch"
                );
            }
            TransferHelper.safeTransferNative(receiver, amount);
        } else if (burnable) {
            uint256 old = IERC20(receiveToken).balanceOf(receiver);
            IMintBurnToken(receiveToken).mint(receiver, amount);
            uint256 val = IERC20(receiveToken).balanceOf(receiver);
            require(val == old + amount, "MP: mint failed");
        } else {
            IERC20(receiveToken).safeTransferFrom(
                liquidpool(),
                receiver,
                amount
            );
        }
        emit LogVaultIn(receiveToken, orderID, receiver, amount, 0, 0);
    }

    // Fees[] struct
    // 0: uint256 expectAmount
    // 1: uint256 minAmount
    // 2: uint256 feeRate
    // 3: uint256 gasFee
    function vaultInAndCall(
        uint256 orderID,
        address tokenAddr,
        address toAddr,
        bool burnable,
        uint256 amount,
        address receiver,
        address receiveToken,
        uint256[] memory fees,
        bytes calldata data
    ) external onlyController whenNotPaused {
        require(orderID > 0, "MP: orderID empty");
        require(data.length > 0, "MP: data empty");
        require(fees.length == 4, "MP: fees mismatch");
        require(amount > 0, "MP: amount is empty");
        require(fees[1] > 0, "MP: minAmount is empty");
        require(fees[0] > 0, "MP: expectAmount is empty");
        if (!burnable) {
            require(
                _balanceOf(tokenAddr) >= amount,
                "MP: insufficient balance"
            );
        }
        require(receiver != address(0), "MP: receiver is empty");
        require(
            toAddr != address(this) && toAddr != address(0),
            "MP: toAddr invaild"
        );
        _registerOrder(orderID);
        bool fromTokenNative = (tokenAddr == NATIVE);
        if (fromTokenNative) {
            if (needWrapNative()) {
                IERC20(wNATIVE).safeTransferFrom(
                    liquidpool(),
                    address(this),
                    amount
                );
                uint256 old = address(this).balance;
                IWrapToken(wNATIVE).withdraw(amount);
                uint256 val = address(this).balance;
                require(
                    val - old == amount,
                    "MP: native token amount dismatch"
                );
            } else {
                // the native token in this contract, so ignore
                require(
                    address(this).balance >= amount,
                    "MP: native token insuffient"
                );
            }
        } else {
            if (burnable) {
                uint256 old = IERC20(tokenAddr).balanceOf(address(this));
                IMintBurnToken(tokenAddr).mint(address(this), amount);
                uint256 val = IERC20(tokenAddr).balanceOf(address(this));
                require(val == old + amount, "MP: mint failed");
            } else {
                IERC20(tokenAddr).safeTransferFrom(
                    _liquidpool,
                    address(this),
                    amount
                );
            }
            if (IERC20(tokenAddr).allowance(address(this), toAddr) < amount) {
                IERC20(tokenAddr).safeApprove(toAddr, MAX_UINT256);
            }
        }

        (uint256 realOut, uint256 serviceFee) = _callAndTransfer(
            toAddr,
            fromTokenNative ? amount : 0,
            receiveToken,
            fees,
            data
        );
        if (receiver != address(this)) {
            if (receiveToken == NATIVE) {
                TransferHelper.safeTransferNative(receiver, realOut);
            } else {
                IERC20(receiveToken).safeTransfer(receiver, realOut);
            }
        }
        uint256 totalfee = serviceFee + fees[3];
        if (totalfee > 0) {
            if (receiveToken == NATIVE) {
                if (needWrapNative()) {
                    IWrapToken(wNATIVE).deposit{value: totalfee}();
                    IERC20(wNATIVE).safeTransfer(_liquidpool, totalfee);
                }
            } else {
                IERC20(receiveToken).safeTransfer(_liquidpool, totalfee);
            }
        }

        emit LogVaultIn(
            receiveToken,
            orderID,
            receiver,
            realOut,
            serviceFee,
            fees[3]
        );
    }

    // Fees[] struct
    // 0: uint256 expectAmount
    // 1: uint256 minAmount
    // 2: uint256 feeRate
    // 3: uint256 gasFee
    function _callAndTransfer(
        address contractAddr,
        uint256 fromNativeAmount,
        address receiveToken,
        uint256[] memory fees,
        bytes calldata data
    ) internal returns (uint256, uint256) {
        uint256 old_balance = _balanceOfSelf(receiveToken);

        if (fromNativeAmount > 0) {
            contractAddr.functionCallWithValue(
                data,
                fromNativeAmount,
                "MP: CallWithValue failed"
            );
        } else {
            contractAddr.functionCall(data, "MP: FunctionCall failed");
        }
        uint256 real = 0;
        uint256 serviceFee = 0;
        {
            uint256 expectAmount = fees[0];
            uint256 minAmount = fees[1];
            uint256 feeRate = fees[2];
            uint256 gasFee = fees[3];
            uint256 new_balance = _balanceOfSelf(receiveToken);
            require(
                new_balance > old_balance,
                "MP: receiver should get assets"
            );
            uint256 amountOut = new_balance - old_balance;
            require(amountOut >= minAmount, "MP: receive amount not enough");
            require(amountOut >= minAmount + gasFee, "MP: gasFee not enough");

            serviceFee = (amountOut * feeRate) / 10000;

            require(
                amountOut >= minAmount + gasFee + serviceFee,
                "MP: fee not enough"
            );
            real = amountOut - serviceFee - gasFee;
            if (real > expectAmount) {
                serviceFee += real - expectAmount;
                real = expectAmount;
            }
        }
        return (real, serviceFee);
    }

    function call(
        address target,
        bytes calldata _data
    ) external payable onlyOwner {
        (bool success, bytes memory result) = target.call{value: msg.value}(
            _data
        );
        emit LogVaultCall(target, msg.value, success, result);
    }

    function withdrawFee(
        address token,
        uint256 amount
    ) external onlyController {
        if (token == NATIVE) {
            uint256 balance = address(this).balance;
            uint256 tmp = balance > amount ? amount : balance;
            TransferHelper.safeTransferNative(owner(), tmp);
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            uint256 tmp = balance > amount ? amount : balance;
            IERC20(token).safeTransfer(owner(), tmp);
        }
    }
}