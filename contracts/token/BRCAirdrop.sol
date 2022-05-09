// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BRCAirdrop is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event NewVault(address oldVault, address newVault);
    event NewVerifier(address oldVerifier, address newVerifier);
    event Claim(address token, address user, uint256 amount);
    address public token;
    address public vault;
    address public verifier;
    mapping(address => uint256) public totalReward;
    mapping(address => uint256) public claimed;

    function setVault(address _vault) external onlyOwner {
        emit NewVault(vault, _vault);
        vault = _vault;
    }

    function setVerifier(address _verifier) external onlyOwner {
        emit NewVerifier(verifier, _verifier);
        verifier = _verifier;
    }

    function setUserClaimed(
        address _user,
        uint256 _amount
    ) external onlyOwner {
        claimed[_user] = _amount;
    }

    constructor(address _token, address _vault, address _verifier) {
        token = _token;
        emit NewVault(vault, _vault);
        vault = _vault;
        emit NewVerifier(verifier, _verifier);
        verifier = _verifier;
    }

    function getEncodePacked(
        address user,
        uint256 amount
    ) public view returns (bytes memory) {
        return abi.encodePacked(token, user, amount);
    }

    function getHash(
        address user,
        uint256 amount
    ) external view returns (bytes32) {
        return keccak256(abi.encodePacked(token, user, amount));
    }

    function getHashToSign(
        address user,
        uint256 amount
    ) external view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(abi.encodePacked(token, user, amount))
                )
            );
    }

    function verify(
        address user,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool) {
        return
            ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19Ethereum Signed Message:\n32",
                        keccak256(
                            abi.encodePacked(token, user, amount)
                        )
                    )
                ),
                v,
                r,
                s
            ) == verifier;
    }

    function claim(
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        address user = msg.sender;
        bytes32 hash = keccak256(
            abi.encodePacked(token, user, amount)
        );
        bytes32 hashToSign = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        require(ecrecover(hashToSign, v, r, s) == verifier, "illegal verifier");
        uint256 realAmount = amount.sub(claimed[user]);
        IERC20(token).safeTransferFrom(vault, user, realAmount);
        claimed[user] = claimed[user].add(realAmount);
        totalReward[token] = totalReward[token].add(realAmount);
        emit Claim(token, user, realAmount);
    }
}
