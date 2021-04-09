// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

/*
                            ___ _____    ___ 
                           /   |  _  |  /   |
  ___ _ __ _ __ ___  _ __ / /| | |/' | / /| |
 / _ \ '__| '__/ _ \| '__/ /_| |  /| |/ /_| |
|  __/ |  | | | (_) | |  \___  \ |_/ /\___  |
 \___|_|  |_|  \___/|_|      |_/\___/     |_/
                                             
 Website: https://error404.finance
 twitter: https://twitter.com/Error404Finance
*/

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract error404Globals is Ownable {
    using SafeMath for uint256;

    // error404 token address
    address public token;
    // address of the nfts
    address public nft;
    // Address of the lottery contract
    address public lottery;
    // Address of the minters contract
    address public minter;
    // Address of the referrals contract
    address public referrals;
    // Developer address where the tokens generated by the chefs fall
    address public devaddr;
    // Fee address for repurchase where the fees deposited by users fall
    address public feeAddress;
    // Address the contract of the profit strategy and add liquidity
    address public reward;

    constructor(
        address _token,
        address _nft,
        address _lottery,
        address _minter,
        address _referrals,
        address _devaddr,
        address _feeAddress,
        address _reward
    ) public {
        token = _token;
        nft = _nft;
        lottery = _lottery;
        minter = _minter;
        referrals = _referrals;
        devaddr = _devaddr;
        feeAddress = _feeAddress;
        reward = _reward;
    }

    // Update dev address.
    function dev(address _addr) external onlyOwner {
        devaddr = _addr;
        emit eventSetDevAddress(msg.sender, _addr);
    }

    // Update fee address.
    function setFeeAddress(address _addr) external onlyOwner{
        feeAddress = _addr;
        emit eventSetFeeAddress(msg.sender, _addr);
    }

    // Update referrals address.
    function setReferralsAddress(address _addr) external onlyOwner{
        referrals = _addr;
        emit eventSetReferralsAddress(msg.sender, _addr);
    }

    // Update minter address.
    function setMinterAddress(address _addr) external onlyOwner{
        minter = _addr;
        emit eventSetMinterAddress(msg.sender, _addr);
    }

    // Update lottery address.
    function setLotteryAddress(address _addr) external onlyOwner{
        lottery = _addr;
        emit eventSetLotteryAddress(msg.sender, _addr);
    }

    // Update nft address.
    function setNFTAddress(address _addr) external onlyOwner{
        nft = _addr;
        emit eventSetNFTAddress(msg.sender, _addr);
    }

    // Update token address.
    function setTokenAddress(address _addr) external onlyOwner{
        token = _addr;
        emit eventSetTokenAddress(msg.sender, _addr);
    }

    // Update reward address.
    function setRewardAddress(address _addr) external onlyOwner{
        reward = _addr;
        emit eventSetRewardAddress(msg.sender, _addr);
    }

    event eventSetDevAddress(address indexed user, address indexed _addr);
    event eventSetFeeAddress(address indexed user, address indexed _addr);
    event eventSetReferralsAddress(address indexed user, address indexed _addr);
    event eventSetMinterAddress(address indexed user, address indexed _addr);
    event eventSetLotteryAddress(address indexed user, address indexed _addr);
    event eventSetNFTAddress(address indexed user, address indexed _addr);
    event eventSetTokenAddress(address indexed user, address indexed _addr);
    event eventSetRewardAddress(address indexed user, address indexed _addr);

}