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
    // list of approved tokens
    mapping(address => bool) public approvals;
    // Router Banana
    IPancakeRouter02 routerBanana = IPancakeRouter02(0xC0788A3aD43d79aa53B09c2EaCc313A787d1d607);
    // Banana token Address
    IERC20 private constant Banana = IERC20(0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95);

    constructor(IGlobals _global) public {
        global = _global;
    }

    // exchange profit tokens for bnb, then send them to the rewards strategy
    function _flipToWBNB(IERC20 _token) internal {
        if(address(_token) != address(WBNB)){
            if(address(_token) == address(Banana)){
                routerBanana.swapExactTokensForTokensSupportingFeeOnTransferTokens(getBalance(_token), uint256(0), global.getPaths(address(_token), 0), address(this), now.add(1800));
            } else {
                router().swapExactTokensForTokensSupportingFeeOnTransferTokens(getBalance(_token), uint256(0), global.getPaths(address(_token), 0), address(this), now.add(1800));
            }
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
        _approve(_tokenA);
        _approve(_tokenB);
        _approve(_lp);
        _approve(WBNB);
        if(address(_tokenA) == address(Banana)){
            _approveBanana(_tokenA);
            _approveBanana(_lp);
        }
        if(_isTokenOnly){
            if(getBalance(_tokenA) > 0){
                _flipToWBNB(_tokenA);
                emit eventConvert(address(_tokenA), address(_tokenB), address(_lp), _isTokenOnly, now);
            }
        } else {
            if(getBalance(_lp) > 0){
                if(address(_tokenA) == address(Banana)){
                    routerBanana.removeLiquidity(address(_tokenA), address(_tokenB), getBalance(_lp), 0, 0, address(this), block.timestamp);
                } else {
                    router().removeLiquidity(address(_tokenA), address(_tokenB), getBalance(_lp), 0, 0, address(this), block.timestamp);
                }
                if(getBalance(_tokenA) > 0 && getBalance(_tokenB) > 0){
                    _flipToWBNB(_tokenA);
                    _flipToWBNB(_tokenB);
                    emit eventConvert(address(_tokenA), address(_tokenB), address(_lp), _isTokenOnly, now);
                }
            }
        }
    }

    // internal function to approve tokens
    function _approve(IERC20 _token) internal {
        if(address(_token) != address(0) && approvals[address(_token)] == false){
            _token.approve(address(router()), uint(~0));
            approvals[address(_token)] = true;
        }
    }

    // internal function to approve tokens to banana
    function _approveBanana(IERC20 _token) internal {
        if(address(_token) != address(0) && approvals[address(_token)] == false){
            _token.approve(address(routerBanana), uint(~0));
            approvals[address(_token)] = true;
        }
    }       

    // returns the balance of the token
    function getBalance(IERC20 _token) public view returns(uint256){
        return _token.balanceOf(address(this));
    }

    // router interface returns
    function router() public view returns(IPancakeRouter02) {
        IPancakeRouter02 _router = IPancakeRouter02(global.router());
        return _router;
    }

    event eventConvert(address indexed _tokenA, address indexed _tokenB, address indexed _lp, bool _isTokenOnly, uint256 _time);

}