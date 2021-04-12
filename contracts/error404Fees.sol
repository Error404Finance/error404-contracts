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
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libs/IPancakeRouter02.sol";
import "./libs/IGlobals.sol";
import "./libs/IHelper.sol";

contract error404Fees is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Address of the global variables assignment contract
    IGlobals public global;
    // WBNB token address
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    // Pancake swap router address
    IPancakeRouter02 public router = IPancakeRouter02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);

    constructor(IGlobals _global) public {
        global = _global;
    }

    // exchange profit tokens for bnb, then send them to the rewards strategy
    function _flipToWBNB(IERC20 _token) internal {
        if(address(_token) != address(WBNB)){
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(getBalance(_token), uint256(0), global.paths(address(_token), 0), address(this), now.add(1800));
            if(getBalance(WBNB) > 0){
                if(global.feeDevs() > 0){
                    WBNB.safeTransfer(global.devaddr(), getBalance(WBNB).mul(global.feeDevs()).div(100 ether));
                }
                WBNB.safeTransfer(global.reward(), getBalance(WBNB));
            }
        }
    }

    // function that removes the lp and the tokens, exchanges them for wbnb and sends them to the profits strategy
    function convert(IERC20 _tokenA, IERC20 _tokenB, IERC20 _lp, bool _isTokenOnly) external {
        if(_isTokenOnly){
            if(getBalance(_tokenA) > 0){
                _flipToWBNB(_tokenA);
                emit eventConvert(address(_tokenA), address(_tokenB), address(_lp), _isTokenOnly, now);
            }
        } else {
            if(getBalance(_lp) > 0){
                router.removeLiquidity(address(_tokenA), address(_tokenB), getBalance(_lp), 0, 0, address(this), block.timestamp);
                if(getBalance(_tokenA) > 0 && getBalance(_tokenB) > 0){
                    _flipToWBNB(_tokenA);
                    _flipToWBNB(_tokenB);
                    emit eventConvert(address(_tokenA), address(_tokenB), address(_lp), _isTokenOnly, now);
                }
            }
        }
    }

    // returns the balance of the token
    function getBalance(IERC20 _token) public view returns(uint256){
        return _token.balanceOf(address(this));
    }

    event eventConvert(address indexed _tokenA, address indexed _tokenB, address indexed _lp, bool _isTokenOnly, uint256 _time);

}