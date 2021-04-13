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
import "./libs/IPancakeFactory.sol";
import "./libs/IGlobals.sol";
import "./libs/IStrategy.sol";
import "./libs/IMintable.sol";
import "./libs/IHelper.sol";

contract error404Profits is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Smart contract helper address
    IHelper public helper;
    // Address of the global variables assignment contract
    IGlobals public global;
    // Strategy direction, if it is address 0, the pool has no strategy
    IStrategy public strategy;
    // strategy pool id
    uint256 public pid;
    // Address of the earnings token of the assigned strategy
    IERC20 public reward;
    // error404 token address
    IERC20 public token;
    // error404 pool address
    IStrategy public pool404;
    // allowed direction to import
    address public importer;
    
    // MasterChef type to organize calls to strategy
    //   0. Global
    //   1. PancakeSwap
    uint256 public typeChef;

    // Token A address
    IERC20 public tokenA;
    // Token B address
    IERC20 public tokenB;
    // Token LP address
    IERC20 public tokenLP;
    
    // WBNB token address
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    // BUSD token address
    IERC20 private constant BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);      
    // Pancake swap router address
    IPancakeRouter02 public router = IPancakeRouter02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
    // Pancake swap factory address
    IPancakeFactory private constant factory = IPancakeFactory(0xBCfCcbde45cE874adCB698cC183deBcF17952812);    
    // Address Burn
    address dead = 0x000000000000000000000000000000000000dEaD;
    // list of approved tokens
    mapping(address => mapping(address => bool)) public approvals;
    // List Mods
    mapping(address => bool) private _mods;

    constructor(
        IStrategy _strategy,
        IERC20 _reward,
        uint256 _typeChef,
        uint256 _pid,
        IERC20 _tokenA,
        IERC20 _tokenB,
        IERC20 _tokenLP,
        IERC20 _token,
        IHelper _helper,
        IGlobals _global,
        address _importer
    ) public {
        setMod(msg.sender, true);
        strategy = _strategy;
        reward = _reward;
        typeChef = _typeChef;
        pid = _pid;
        token = _token;
        helper = _helper;
        global = _global;
        tokenA = _tokenA;
        tokenB = _tokenB;
        tokenLP = _tokenLP;
        importer = _importer;
        _approve(token, address(router));
        _approve(WBNB, address(router));
        _approve(BUSD, address(router));
        _approve(reward, address(router));
        _approve(tokenA, address(router));
        _approve(tokenB, address(router));
        _approve(tokenLP, address(router));
        _approve(reward, address(strategy));
        _approve(tokenA, address(strategy));
        _approve(tokenB, address(strategy));
        _approve(tokenLP, address(strategy));
    }

    // function to assign error404 pool address
    function setPool(IStrategy _pool404) external onlyOwner {
        require(address(_pool404) != address(0), "!pool404");
        pool404 = _pool404;
        IERC20 lp404 = IERC20(factory.getPair(address(token), address(WBNB)));
        _approve(lp404, address(pool404));
        emit eventSetPool(now);
    }

    // exchange tokens for tokens
    function _flipTokens(IERC20 _token, uint256 _amount, uint256 _type) internal {
        if(_amount > 0 && address(_token) != address(WBNB)){
            _approve(_token, address(router));
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), global.getPaths(address(_token), _type), address(this), now.add(1800));
        }
    }   

    // Deposit and extract rewards from the strategy
    function _farm(uint256 _amount) internal {
        if(typeChef == 1){
            strategy.enterStaking(_amount);
        } else {
            strategy.deposit(pid, _amount);
        }
    }

    // Deposit the rewards in the strategy and reinvest the profits
    function deposit(bool _harvest, uint256 _start, uint256 _end) public onlyMods {
        if(_harvest){
            if(_start == 0 && _end == 0){
                helper.harvestAll();
            } else {
                helper.harvest(_start, _end);
            }
        }        
        if(address(tokenA) != address(0) && address(tokenB) == address(0)){
            _farm(0);
            _flipTokens(reward, getBalance(reward), 0);
            _flipTokens(tokenA, getBalance(tokenA), 0);
            _flipTokens(tokenA, getBalance(WBNB), 1);
            _farm(getBalance(tokenA));
            emit eventDeposit(now);
        } else if(address(tokenA) != address(0) && address(tokenB) != address(0) && address(factory.getPair(address(tokenA), address(tokenB))) == address(tokenLP)){
            _farm(0);
            _flipTokens(reward, getBalance(reward), 0);
            uint256 amountB = 0;
            if(address(tokenB) == address(WBNB)){
                _flipTokens(tokenA, getBalance(tokenA), 0);
                _flipTokens(tokenA, getBalance(WBNB).div(2), 1);
                amountB = getBalance(WBNB);
            } else if(address(tokenB) == address(BUSD)){
                _flipTokens(BUSD, getBalance(BUSD), 0);
                _flipTokens(tokenA, getBalance(tokenA), 0);
                _flipTokens(BUSD, getBalance(WBNB), 1);
                _flipTokens(tokenA, getBalance(BUSD).div(2), 1);
                amountB = getBalance(BUSD);
            }
            if(getBalance(tokenA) > 0 && amountB > 0){
                router.addLiquidity(
                    address(tokenA),
                    address(tokenB),
                    getBalance(tokenA),
                    amountB,
                    0,
                    0,
                    address(this),
                    now.add(1800)
                );
                if(getBalance(tokenLP) > 0){
                    _farm(getBalance(tokenLP));
                }
            }
            emit eventDeposit(now);
        }
    }

    // Internal function to generate profits for error404
    function _profits() internal {
        _farm(0);
        _flipTokens(reward, getBalance(reward), 0);
        if(global.feeDevs() > 0){
            WBNB.safeTransfer(global.devaddr(), getBalance(WBNB).mul(global.feeDevs()).div(100 ether));
        }
        IERC20 lp404 = IERC20(factory.getPair(address(token), address(WBNB)));
        uint256 balanceToken = getBalanceToken(lp404, token);
        uint256 balanceWBNB = getBalanceToken(lp404, WBNB);
        uint256 amountWBNB = getBalance(WBNB);
        uint256 oneHundred = 100 ether;
        uint256 percentageWBNB = oneHundred.mul(amountWBNB).div(balanceWBNB);
        uint256 percentageToken = oneHundred.mul(oneHundred).div(balanceToken);
        uint256 tokensToSend = percentageWBNB.mul(oneHundred).div(percentageToken);
        IMintable(address(global.minter())).mint(tokensToSend, address(this));
        router.addLiquidity(
            address(token),
            address(WBNB),
            tokensToSend,
            amountWBNB,
            0,
            0,
            address(this),
            now.add(1800)
        );
        if(getBalance(lp404) > 0){
            pool404.deposit(getBalance(lp404), address(0));
        }
        if(getBalance(token) > 0){
            token.safeTransfer(dead, getBalance(token));
        }
    }

    // The profits of the strategy are added by liquidity with error404 and WBNB
    function profits(bool _harvest, uint256 _start, uint256 _end) external onlyMods {
        if(_harvest){
            if(_start == 0 && _end == 0){
                helper.harvestAll();
            } else {
                helper.harvest(_start, _end);
            }
        }
        _profits();
        emit eventProfits(now);
    }

    // Function to remove liquidity and sell tokens by wbnb
    function _closeProfits() internal {
        _farm(0);
        _flipTokens(reward, getBalance(reward), 0);
        _flipTokens(tokenB, getBalance(tokenB), 0);
        _flipTokens(tokenA, getBalance(tokenA), 0);
        strategy.emergencyWithdraw(pid);
        if(address(tokenA) != address(0) && address(tokenB) == address(0)){
            _flipTokens(tokenA, getBalance(tokenA), 0);
        } else if(address(tokenA) != address(0) && address(tokenB) != address(0) && address(factory.getPair(address(tokenA), address(tokenB))) == address(tokenLP)){
            if(getBalance(tokenLP) > 0){
                router.removeLiquidity(address(tokenA), address(tokenB), getBalance(tokenLP), 0, 0, address(this), block.timestamp);
            }
            _flipTokens(tokenB, getBalance(tokenB), 0);
            _flipTokens(tokenA, getBalance(tokenA), 0);
        }
    }

    // Function to remove liquidity and sell tokens by wbnb
    function closeProfits() external onlyMods {
        _closeProfits();
        _profits();
        emit eventCloseProfits(now);
    }

    // Function to change the strategy to obtain better profits.
    function changeStrategy(IStrategy _strategy, IERC20 _reward, uint256 _typeChef, uint256 _pid, IERC20 _tokenA, IERC20 _tokenB, IERC20 _tokenLP) external onlyOwner {
        if(address(strategy) != address(0) && address(_reward) != address(0)){
            _closeProfits();
            strategy = _strategy;
            reward = _reward;
            typeChef = _typeChef;
            pid = _pid;
            tokenA = _tokenA;
            tokenB = _tokenB;
            tokenLP = _tokenLP;
            _approve(reward, address(router));
            _approve(tokenA, address(router));
            _approve(tokenB, address(router));
            _approve(tokenLP, address(router));
            _approve(reward, address(strategy));
            _approve(tokenA, address(strategy));
            _approve(tokenB, address(strategy));
            _approve(tokenLP, address(strategy));
            deposit(false, 0, 0);
            emit eventChangeStrategy(address(reward), address(strategy), address(tokenA), address(tokenB), address(tokenLP), now);
        }
    }

    // internal function to approve tokens
    function _approve(IERC20 _token, address _to) internal {
        if(address(_token) != address(0) && approvals[address(_token)][_to] == false){
            _token.approve(_to, uint(~0));
            approvals[address(_token)][_to] = true;
        }
    }

    // function to approve tokens
    function approveTokens(IERC20 _token, address _to) external onlyMods {
        _approve(_token, _to);
        emit eventApproveTokens(address(_token), _to, now);
    }

    // returns the balance of the token
    function getBalance(IERC20 _token) public view returns(uint256){
        return _token.balanceOf(address(this));
    }

    // returns the balance of the token
    function getBalanceToken(IERC20 _token, IERC20 _lp) public view returns(uint256){
        return _lp.balanceOf(address(_token));
    }

    // Only mods
    modifier onlyMods {
        require(isMod(msg.sender) == true, "error404Profits: caller is not the mods");
        _;
    }  

    // Check if it is an address with permission of mod
    function isMod(address account) public view returns (bool) {
        return _mods[account];
    }

    // Add and remove a mod
    function setMod(address mod, bool canMod) public onlyOwner {
        if (canMod) {
            _mods[mod] = canMod;
        } else {
            delete _mods[mod];
        }
        emit eventSetMod(mod, canMod);
    }

    // Function to recover lost tokens
    function recoverBEP20(IERC20 _token, address[] calldata _path) external onlyOwner {
        uint256 _amount = getBalance(_token);
        if(_amount > 0){
            _approve(_token, address(router));
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, uint256(0), _path, address(this), now.add(1800));
            emit Recovered(address(_token), _amount);
        }
    }

    // Function to recover lost tokensLP
    function recoverLP(IERC20 _tokenA, IERC20 _tokenB) external onlyOwner {
        IERC20 lp = IERC20(factory.getPair(address(_tokenA), address(_tokenB)));
        uint256 _amount = getBalance(lp);
        if(_amount > 0){
            _approve(lp, address(router));
            router.removeLiquidity(address(_tokenA), address(_tokenB), _amount, 0, 0, address(this), block.timestamp);
            emit RecoveredLP(address(_tokenA), address(_tokenB), _amount);
        }
    }

    // leave the farms
    function leaveFarms() external onlyOwner {
        _farm(0);
        strategy.emergencyWithdraw(pid);
        emit eventLeaveFarms(now);
    }

    // leave the farm
    function leaveFarm() external onlyOwner {
        _farm(0);
        emit eventLeaveFarm(now);
    }

    // leave the farm emergencyWithdraw
    function leaveFarmEmergencyWithdraw() external onlyOwner {
        strategy.emergencyWithdraw(pid);
        emit eventLeaveFarmEmergencyWithdraw(now);
    }

    // emergency withdrawal and convert all tokens to WBNB
    function emergencyWithdraw() public onlyOwner {
        _closeProfits();
        emit eventEmergencyWithdraw(now);
    }

    // Change profit strategy
    function changeProfitsStrategy(address _newProfit, bool _closed) public onlyOwner {
        if(_closed){
            _closeProfits();
        }
        uint256 _amount = getBalance(WBNB);
        _approve(WBNB, _newProfit);
        IHelper(_newProfit).importProfit(_amount);
        emit eventChangeProfitsStrategy(address(this), _newProfit, _amount, now);
    }

    // Import the WBNB tokens from the old strategy
    function importProfit(uint256 _amount) external {
        require(importer == msg.sender, "!importer");
        WBNB.safeTransferFrom(address(msg.sender), address(this), _amount);
        deposit(false, 0, 0);
        emit eventImportProfit(_amount, now);
    }

    event eventSetMod(address _mod, bool _canMod);
    event eventDeposit(uint256 _time);
    event eventProfits(uint256 _time);
    event eventCloseProfits(uint256 _time);
    event eventSetPool(uint256 _time);    
    event eventChangeStrategy(address _reward, address _strategy, address _tokenA, address _tokenB, address _tokenLP, uint256 _time);
    event Recovered(address _token, uint256 _amount);
    event RecoveredLP(address _tokenA, address _tokenB, uint256 _amount);
    event eventEmergencyWithdraw(uint256 _time);
    event eventChangeProfitsStrategy(address _last, address _new, uint256 _amount, uint256 _time);
    event eventImportProfit(uint256 _amount, uint256 _time);
    event eventLeaveFarms(uint256 _time);
    event eventLeaveFarm(uint256 _time);
    event eventLeaveFarmEmergencyWithdraw(uint256 _time);
    event eventApproveTokens(address _token, address _to, uint256 _time);
    
}