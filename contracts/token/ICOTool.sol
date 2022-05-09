// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract ICOTool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    uint256 public constant BASE_RATIO = 10**18;
    uint256 public remaining;
    IERC20 public currency;
    IERC20 public icoToken;
    uint256 public price;
    uint256 public icoLimitPerUser;
    address public vault;
    uint256 public startTime;
    uint256 public endTime;
    mapping(address => UserInfo) public userInfos;

    struct UserInfo {
        uint256 amount;
        uint8 collectState;
    }

    event Subscribe(address account, uint256 value);
    event Collect(address account, uint256 value);

    constructor(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _remaining,
        address _icoToken,
        address _currency,
        uint256 _price,
        address _vault,
        uint256 _icoLimitPerUser
    ) {
        startTime = _startTime;
        endTime = _endTime;
        remaining = _remaining;
        icoToken = IERC20(_icoToken);
        currency = IERC20(_currency);
        price = _price;
        vault = _vault;
        icoLimitPerUser = _icoLimitPerUser;
    }

    function subscribe(uint256 value) external {
        require(block.timestamp > startTime, "ico not started");
        require(block.timestamp < endTime, "ico has ended");
        UserInfo storage user = userInfos[msg.sender];
        require(
            icoLimitPerUser == 0 || user.amount.add(value) <= icoLimitPerUser,
            "User amount above limit"
        );
        remaining = remaining.sub(value, "Insufficient remaining amount");
        user.amount = user.amount.add(value);
        currency.safeTransferFrom(
            msg.sender,
            vault,
            value.mul(price).div(BASE_RATIO)
        );
        emit Subscribe(msg.sender, value);
    }

    function collect() external {
        require(block.timestamp > endTime, "ico not settled");
        UserInfo storage user = userInfos[msg.sender];
        uint256 amount = harvest(msg.sender);
        if (block.timestamp.sub(endTime) > 60 days) {
            user.collectState = 3;
        } else if (block.timestamp.sub(endTime) > 30 days) {
            user.collectState = 2;
        } else {
            user.collectState = 1;
        }
        icoToken.safeTransfer(msg.sender, amount);

        emit Collect(msg.sender, amount);
    }

    function harvest(address account) public view returns (uint256) {
        UserInfo memory user = userInfos[account];
        uint256 amount;
        if (block.timestamp.sub(endTime) > 60 days) {
            if (user.collectState == 0) {
                amount = user.amount;
            } else if (user.collectState == 1) {
                amount = user.amount.mul(80).div(100);
            } else if (user.collectState == 2) {
                amount = user.amount.mul(50).div(100);
            }
        } else if (block.timestamp.sub(endTime) > 30 days) {
            if (user.collectState == 0) {
                amount = user.amount.mul(50).div(100);
            } else if (user.collectState == 1) {
                amount = user.amount.mul(30).div(100);
            }
        } else {
            if (user.collectState == 0) {
                amount = user.amount.mul(20).div(100);
            }
        }
        return amount;
    }
}
