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
import "./libs/IPancakeFactory.sol";
import "./libs/IGlobals.sol";
import "./libs/IChef.sol";
import "./libs/IFees.sol";
import "./libs/IHelper.sol";

contract error404Helper is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Address of the global variables assignment contract
    IGlobals public global;

    // Address of the fee contract
    IFees public FEES;

    // Lp CAKE_WBNB token address
    address public CAKE_POOL = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;
    // Lp BNB_BUSD_POOL token address
    address public BNB_BUSD_POOL = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    
    // WBNB token address
    IERC20 private constant WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    // CAKE token address
    IERC20 private constant CAKE = IERC20(0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82);
    // BUSD token address
    IERC20 private constant BUSD = IERC20(0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56);
    // Banana token Address
    IERC20 private constant Banana = IERC20(0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95);
    // Factory Banana
    IPancakeFactory factoryBanana = IPancakeFactory(0x0841BD0B734E4F5853f0dD8d7Ea041c241fb0Da6);

    // Info of each pool.
    struct PoolInfo {
        IChef strategy;             // Farm Strategy Address
        IERC20 tokenA;              // Address of tokenA contract.
        IERC20 tokenB;              // Address of tokenA contract.
        IERC20 lp;                  // Address of LP token contract.
        bool isTokenOnly;           // Check if it is a token only or is it an LP
        string farm;                // Farm name
        string tokenSymbol;         // Token A symbol
        string quoteTokenSymbol;    // Token B symbol
        string provider;            // Strategy provider name
        bool status;                // Farm status
    }

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // List of strategies in the helper
    mapping(address => bool) public farms;

    constructor(IFees _FEES, IGlobals _global) public {
        FEES = _FEES;
        global = _global;
    }    

    // Returns the total farms
    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    // Function to add a new farm
    function addFarm(IChef _strategy, IERC20 _tokenA, IERC20 _tokenB, IERC20 _lp, bool _isTokenOnly, string memory _farm, string memory _tokenSymbol, string memory _quoteTokenSymbol, string memory _provider) external onlyOwner {
        require(farms[address(_strategy)] == false, "strategy already exists");
        poolInfo.push(PoolInfo({
            strategy: _strategy,
            tokenA: _tokenA,
            tokenB: _tokenB,
            lp: _lp,
            isTokenOnly: _isTokenOnly,
            farm: _farm,
            tokenSymbol: _tokenSymbol,
            quoteTokenSymbol: _quoteTokenSymbol,
            provider: _provider,
            status: true
        }));
        emit eventAddFarm(address(_strategy), poolInfo.length.sub(1), now);
        farms[address(_strategy)] = true;
    }

    // Function to change strategy and provider to a specific farm
    function setFarm(uint256 _pid, IChef _strategy, string memory _provider) external onlyOwner {
        require(farms[address(_strategy)] == false, "strategy already exists");
        require(address(poolInfo[_pid].tokenA) != address(0), "non-existent farm");
        poolInfo[_pid].strategy = _strategy;
        poolInfo[_pid].provider = _provider;
        emit eventSetFarm(address(_strategy), _pid, now);
    }

    // It worked to stop a farm and not show it in the ui
    function stopFarm(uint256 _pid) external onlyOwner {
        require(address(poolInfo[_pid].tokenA) != address(0), "non-existent farm");
        require(poolInfo[_pid].status == true, "farm stopped");
        poolInfo[_pid].status = false;
        emit eventStopFarm(_pid, now);
    }

    // Returns the price of a token in BNB
    function tokenPriceInBNB(address _token) public view returns(uint) {
        address pair = address(0);
        if(_token == address(Banana)){
            pair = factoryBanana.getPair(_token, address(WBNB));
        } else {
            pair = factory().getPair(_token, address(WBNB));
        }
        uint decimal = uint(ERC20(_token).decimals());
        return WBNB.balanceOf(pair).mul(10**decimal).div(IERC20(_token).balanceOf(pair));
    }

    // Returns the price of cake in bnb
    function cakePriceInBNB() public view returns(uint) {
        return WBNB.balanceOf(CAKE_POOL).mul(1e18).div(CAKE.balanceOf(CAKE_POOL));
    }

    // Returns the price of bnb in usd
    function bnbPriceInUSD() public view returns(uint) {
        return BUSD.balanceOf(BNB_BUSD_POOL).mul(1e18).div(WBNB.balanceOf(BNB_BUSD_POOL));
    }

    // Returns the price of a token in usd
    function tokenPriceInUSD(address _token) public view returns(uint) {
        uint priceInBNB = tokenPriceInBNB(_token);
        uint priceBNB = bnbPriceInUSD();
        return priceBNB.mul(priceInBNB);
    }    

    // Function that returns general values of the farm tokens
    function getFarm(uint256 _pid) public view returns(uint256, uint256, uint256, uint256, uint256, uint256){
        PoolInfo storage pool = poolInfo[_pid];
        uint256 balanceOf_tokenA = pool.tokenA.balanceOf(address(pool.lp));
        uint256 balanceOf_tokenB = pool.tokenB.balanceOf(address(pool.lp));
        uint256 totalSupply = pool.lp.totalSupply();
        uint256 decimals_tokenA = ERC20(address(pool.tokenA)).decimals();
        uint256 decimals_tokenB = ERC20(address(pool.tokenB)).decimals();
        return (balanceOf_tokenA, balanceOf_tokenB, totalSupply, decimals_tokenA, decimals_tokenB, pool.strategy.pid());
    }

    // Function that returns general values of the farm tokens
    function getFarmChef(uint256 _pid) public view returns(uint256, uint256, uint256, uint256, address){
        PoolInfo storage pool = poolInfo[_pid];
        return pool.strategy.infoForHelper();
    }

    // function to harvest all strategies
    function harvestAll() external {
        uint256 totalFarms = poolLength();
        if(totalFarms > 0){
            for (uint256 i = 0; i < totalFarms; i++) {
                poolInfo[i].strategy.harvest();
                FEES.convert(address(poolInfo[i].tokenA), address(poolInfo[i].tokenB), address(poolInfo[i].lp), poolInfo[i].isTokenOnly);
            }
            emit eventHarvestAll(now);
        }
    }

    // function to harvest certain strategies
    function harvest(uint256 _start, uint256 _end) external {
        uint256 totalFarms = poolLength();
        if(totalFarms > 0 && totalFarms >= _end){
            for (uint256 i = _start; i <= _end; i++) {
                poolInfo[i].strategy.harvest();
                FEES.convert(address(poolInfo[i].tokenA), address(poolInfo[i].tokenB), address(poolInfo[i].lp), poolInfo[i].isTokenOnly);
            }
            emit eventHarvest(_start, _end, now);
        }
    }

    // function to harvest a user and send the pending earnings tokens
    function harvestAllUser(IChef[] calldata _chefs) external {
        uint256 _length =  _chefs.length;
        for (uint256 i = 0; i < _length; i++) {
            _chefs[i].harvestExternal(msg.sender);
        }
    }

    // function to change the CAKE_POOL address
    function changeCakePool(address _pool) external onlyOwner {
        CAKE_POOL = _pool;
        emit eventChangeCakePool(address(_pool), now);
    }

    // function to change the BNB_BUSD_POOL address
    function changeBNB_BUSDPool(address _pool) external onlyOwner {
        BNB_BUSD_POOL = _pool;
        emit eventChangeBNB_BUSDPool(address(_pool), now);
    }

    // factory interface returns
    function factory() public view returns(IPancakeFactory) {
        IPancakeFactory _factory = IPancakeFactory(global.factory());
        return _factory;
    }

    event eventChangeCakePool(address _pool, uint256 _time);
    event eventChangeBNB_BUSDPool(address _pool, uint256 _time);
    event eventAddFarm(address indexed _strategy, uint256 indexed _pid, uint256 _time);
    event eventSetFarm(address indexed _strategy, uint256 indexed _pid, uint256 _time);
    event eventStopFarm(uint256 indexed _pid, uint256 _time);
    event eventHarvestAll(uint256 _time);
    event eventHarvest(uint256 _start, uint256 _end, uint256 _time);

}