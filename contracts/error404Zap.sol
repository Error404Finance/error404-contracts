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
import "./libs/IWBNB.sol";
import "./libs/IHelper.sol";

contract error404Zap is Ownable {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Address of the global variables assignment contract
    IGlobals public global;

    // WBNB token address
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    
    // list of approved tokens
    mapping(address => mapping(address => bool)) public approvals;

    constructor(IGlobals _global) public {
        global = _global;
    }   

    // the contract can receive bnb
    receive() external payable {}

    // exchange BNB for a specific token
    function zapBNBforToken(address[] calldata _path) external payable {
        require(msg.value > 0, "!value BNB");
        IWBNB _wbnb = IWBNB(address(WBNB));
        uint256 _value = msg.value;
        _wbnb.deposit{value: _value}();
        _approve(WBNB, address(router()));
        router().swapExactTokensForTokensSupportingFeeOnTransferTokens(_value, uint256(0), _path, msg.sender, now.add(1800));
        uint256 _amount = getBalance(WBNB);
        if(_amount > 0){
            _wbnb.withdraw(_amount);
            payable(msg.sender).transfer(_amount);
        }
    }

    // exchange a token for another token
    function zapTokenforToken(IERC20 _token, uint256 _value, address[] calldata _path) external {
        require(_value > 0, "!value Token");
        _token.safeTransferFrom(address(msg.sender), address(this), _value);
        _approve(_token, address(router()));
        router().swapExactTokensForTokensSupportingFeeOnTransferTokens(_value, uint256(0), _path, msg.sender, now.add(1800));
        if(getBalance(_token) > 0){
            _token.safeTransfer(msg.sender, getBalance(_token));
        }
    }

    // exchange a token for BNB
    function zapTokenforBNB(IERC20 _token, uint256 _value, address[] calldata _path) external {
        require(_value > 0, "!value Token");
        _token.safeTransferFrom(address(msg.sender), address(this), _value);
        _approve(_token, address(router()));
        router().swapExactTokensForETHSupportingFeeOnTransferTokens(_value, uint256(0), _path, msg.sender, now.add(1800));
        if(getBalance(_token) > 0){
            _token.safeTransfer(msg.sender, getBalance(_token));
        }
    }

    // adds liquidity to a pair with BNB
    function zapAddLiquidityForBNB(IERC20 _tokenA, IERC20 _tokenB, address[] calldata _pathA, address[] calldata _pathB) external payable {
        require(msg.value > 0, "!value BNB");
        uint256 _value = msg.value;
        IWBNB _wbnb = IWBNB(address(WBNB));
        _wbnb.deposit{value: _value}();
        _approve(WBNB, address(router()));
        _approve(_tokenA, address(router()));
        _approve(_tokenB, address(router()));
        _zapAddLiquidity(_tokenA, _tokenB, _value, _pathA, _pathB);
        uint256 _amountWBNB = getBalance(WBNB);
        if(_amountWBNB > 0){
            _wbnb.withdraw(_amountWBNB);
            payable(msg.sender).transfer(_amountWBNB);
        }
        _zapSendSurplus(_tokenA, _tokenB);
    }

    // adds liquidity to a pair with a token
    function zapAddLiquidityForToken(IERC20 _token, IERC20 _tokenA, IERC20 _tokenB, uint256 _value, address[] calldata _pathA, address[] calldata _pathB) external {
        require(_value > 0, "!value Token");
        _token.safeTransferFrom(address(msg.sender), address(this), _value);
        _approve(WBNB, address(router()));
        _approve(_token, address(router()));
        _approve(_tokenA, address(router()));
        _approve(_tokenB, address(router()));
        _zapAddLiquidity(_tokenA, _tokenB, _value, _pathA, _pathB);
        if(getBalance(_token) > 0){
            _token.safeTransfer(msg.sender, getBalance(_token));
        }
        _zapSendSurplus(_tokenA, _tokenB);
    }

    // removes liquidity and sends the tokens to the user
    function zapRemoveLiquidity(IERC20 _lp, IERC20 _tokenA, IERC20 _tokenB, uint256 _value) external {
        require(_value > 0, "!value Token");
        _lp.safeTransferFrom(address(msg.sender), address(this), _value);
        _approve(_lp, address(router()));
        router().removeLiquidity(address(_tokenA), address(_tokenB), _value, 0, 0, msg.sender, now.add(1800));
        if(getBalance(_lp) > 0){
            _lp.safeTransfer(msg.sender, getBalance(_lp));
        }
        _zapSendSurplus(_tokenA, _tokenB);
    }

    // Function to recover lost tokens
    function recoverBEP20(IERC20 _token) external onlyOwner {
        uint256 _amount = getBalance(_token);
        if(_amount > 0){
            _token.safeTransfer(owner(), _amount);
            emit Recovered(address(_token), _amount);
        }
    }

    // Function to recover lost BNB
    function recoverBNB() external onlyOwner {
        uint256 _amount = address(this).balance;
        if(_amount > 0){
            payable(owner()).transfer(_amount);
            emit Recovered(address(0), _amount);
        }
    }    

    // internal function to add liquidity
    function _zapAddLiquidity(IERC20 _tokenA, IERC20 _tokenB, uint256 _value, address[] calldata _pathA, address[] calldata _pathB) internal {
        if(address(_tokenB) == address(WBNB)){
            router().swapExactTokensForTokensSupportingFeeOnTransferTokens(getBalance(WBNB).div(2), uint256(0), _pathA, address(this), now.add(1800));
        } else {
            if(_pathB.length > 0){
                router().swapExactTokensForTokensSupportingFeeOnTransferTokens(_value, uint256(0), _pathB, address(this), now.add(1800));
            }
            router().swapExactTokensForTokensSupportingFeeOnTransferTokens(getBalance(_tokenB).div(2), uint256(0), _pathA, address(this), now.add(1800));
        }
        router().addLiquidity(
            address(_tokenA),
            address(_tokenB),
            getBalance(_tokenA),
            getBalance(_tokenB),
            0,
            0,
            msg.sender,
            now.add(1800)
        );
    }

    // internal function to send the surplus to the user
    function _zapSendSurplus(IERC20 _tokenA, IERC20 _tokenB) internal {
        if(getBalance(_tokenA) > 0){
            _tokenA.safeTransfer(msg.sender, getBalance(_tokenA));
        }
        if(getBalance(_tokenB) > 0){
            _tokenB.safeTransfer(msg.sender, getBalance(_tokenB));
        }
    }

    // returns the balance of the token
    function getBalance(IERC20 _token) public view returns(uint256){
        return _token.balanceOf(address(this));
    }

    // internal function to approve tokens
    function _approve(IERC20 _token, address _to) internal {
        if(address(_token) != address(0) && approvals[address(_token)][_to] == false){
            _token.approve(_to, uint(~0));
            approvals[address(_token)][_to] = true;
        }
    }

    // router interface returns
    function router() public view returns(IPancakeRouter02) {
        IPancakeRouter02 _router = IPancakeRouter02(global.router());
        return _router;
    }

    event Recovered(address _token, uint256 _amount);

}