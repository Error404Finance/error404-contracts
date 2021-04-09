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
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libs/IMintable.sol";
import "./libs/IStrategy.sol";
import "./libs/IGlobals.sol";

contract error404Chef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Tokens
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accTokenPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accTokenPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;                 // Address of LP token contract.
        uint256 allocPoint;             // How many allocation points assigned to this pool. Tokens to distribute per block.
        uint256 lastRewardBlock;        // Last block number that Tokens distribution occurs.
        uint256 accTokenPerShare;       // Accumulated Tokens per share, times 1e12. See below.
        uint256 depositFee;             // Deposit fee for token buyback
        uint256 feeStra;                // Deposit fee of the strategies used
        bool strategy;                  // Status to check if the pool uses a strategy
        uint256 amount;                 // How much LP has been deposited into the pool
    }

    // Address of the earnings token of the assigned strategy
    IERC20 public reward;
    // Strategy direction, if it is address 0, the pool has no strategy
    IStrategy public strategy;
    // Address of the global variables assignment contract
    IGlobals public global;
    // The block number when tokens mining starts.
    uint256 public tokenPerBlock;
    // Bonus muliplier for early tokens makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // strategy pool id
    uint256 public pid;
    // strategy utilization status
    bool public stop;
    
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    
    // MasterChef type to organize calls to strategy
    //   0. Global
    //   1. PancakeSwap
    uint256 public typeChef;

    constructor(
        IERC20 _lpToken,
        IGlobals _globalsAddr,
        IERC20 _reward,
        IStrategy _strategy,
        uint16 _depositFee,
        uint16 _feeStra,
        bool _checkStrategy,
        uint256 _pid,
        uint256 _tokenPerBlock
    ) public {
        global = _globalsAddr;
        reward = _reward;
        tokenPerBlock = _tokenPerBlock;
        strategy = _strategy;
        uint256 lastRewardBlock = block.number;
        pid = _pid;
        totalAllocPoint = totalAllocPoint.add(1000);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: 1000,
            lastRewardBlock: lastRewardBlock,
            accTokenPerShare: 0,
            depositFee: _depositFee,
            feeStra: _feeStra,
            strategy: _checkStrategy,
            amount: 0
        }));
        _lpToken.safeApprove(address(strategy), uint(~0));
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }
    
    // View function to see pending error404 on frontend.
    function pending(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_user];
        uint256 accTokenPerShare = pool.accTokenPerShare;
        uint256 lpSupply = pool.amount;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accTokenPerShare = accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accTokenPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        PoolInfo storage pool = poolInfo[0];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.amount;
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 tokenReward = multiplier.mul(tokenPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        IMintable(address(global.token())).mint(tokenReward.div(10), global.devaddr());
        IMintable(address(global.token())).mint(tokenReward, address(this));
        pool.accTokenPerShare = pool.accTokenPerShare.add(tokenReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for error404 allocation.
    function deposit(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 _pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
            if(_pending > 0) {
                safeTokenTransfer(msg.sender, _pending);
            }
        }
        uint256 depositFeeBuy = 0;
        uint256 depositFeeStra = 0;  
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            if(pool.depositFee > 0){
                depositFeeBuy = _amount.mul(pool.depositFee).div(10000);
            }
            if(pool.feeStra > 0){
                depositFeeStra = _amount.mul(pool.feeStra).div(10000);
            }
            user.amount = user.amount.add(_amount).sub(depositFeeBuy).sub(depositFeeStra);
            pool.amount = pool.amount.add(_amount).sub(depositFeeBuy).sub(depositFeeStra);
            if(depositFeeBuy > 0){
                pool.lpToken.safeTransfer(global.feeAddress(), depositFeeBuy);
            }
            if(pool.strategy && !stop){
                if(typeChef == 1){
                    strategy.enterStaking(_amount.sub(depositFeeBuy));
                } else {
                    strategy.deposit(pid, _amount.sub(depositFeeBuy));
                }
            }
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        if (user.amount > 0) {
            uint256 _pending = user.amount.mul(pool.accTokenPerShare).div(1e12).sub(user.rewardDebt);
            if(_pending > 0) {
                safeTokenTransfer(msg.sender, _pending);
            }
        }
        if(_amount > 0) {
            if(pool.strategy && !stop){
                if(typeChef == 1){
                    strategy.leaveStaking(_amount);
                } else {
                    strategy.withdraw(pid, _amount);
                }
            }
            user.amount = user.amount.sub(_amount);
            pool.amount = pool.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accTokenPerShare).div(1e12);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        if(pool.strategy && !stop){
            if(typeChef == 1){
                strategy.leaveStaking(amount);
            } else {
                strategy.withdraw(pid, amount);
            }
        }
        pool.amount = pool.amount.sub(amount);
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY STRATEGY.
    function emergencyWithdrawPool() external onlyOwner {
        if(address(strategy) != address(0) && !stop){
            strategy.emergencyWithdraw(pid);
            stop = true;
            emit eventEmergencyWithdrawPool(now);
            emit SetStop(true);
        }
    }    

    // Safe tokens transfer function, just in case if rounding error causes pool to not have enough tokens.
    function safeTokenTransfer(address _to, uint256 _amount) internal {
        IERC20 token = IERC20(address(global.token()));
        uint256 tokenBal = token.balanceOf(address(this));
        if (_amount > tokenBal) {
            token.transfer(_to, tokenBal);
        } else {
            token.transfer(_to, _amount);
        }
    }

    // Pancake has to add hidden dummy pools inorder to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _tokenPerBlock) external onlyOwner {
        updatePool();
        uint256 last_tokenPerBlock = tokenPerBlock;
        tokenPerBlock = _tokenPerBlock;
        emit SetUpdateEmissionRate(last_tokenPerBlock, _tokenPerBlock);
    }

    // We harvest the strategy and the profits obtained are transferred to the strategy to buy and add liquidity to the token.
    function harvest() external {
        if(address(strategy) != address(0) && !stop){
            if(typeChef == 1){
                strategy.enterStaking(0);
            } else {
                strategy.deposit(pid, 0);
            }
            reward.safeTransfer(global.reward(), reward.balanceOf(address(this)));
            emit eventHarvest(now);
        }
    }

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event SetStop(bool _status);
    event eventEmergencyWithdrawPool(uint256 _time);
    event eventHarvest(uint256 _time);
    event SetUpdateEmissionRate(uint256 indexed last_tokenPerBlock, uint256 indexed new_tokenPerBlock);
    
}