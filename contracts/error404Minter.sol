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

import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/SafeBEP20.sol";
import "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import "./libs/IHelper.sol";

contract error404Minter is Ownable {

    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    address public error404; // Address error404
    mapping(address => bool) private _minters; // List Minters

    constructor(address _error404) public {
        error404 = _error404;
    }

    // Only minters
    modifier onlyMinter {
        require(isMinter(msg.sender) == true, "error404Minter: caller is not the minter");
        _;
    }

    // Transfer ownership to a new owner
    function transfer404Owner(address _owner) external onlyOwner {
        Ownable(error404).transferOwnership(_owner);
        emit eventNewOwner(_owner);
    }

    // Add and remove a minter
    function setMinter(address minter, bool canMint) external onlyOwner {
        if (canMint) {
            _minters[minter] = canMint;
        } else {
            delete _minters[minter];
        }
        emit eventSetMinter(minter, canMint);
    }

    // Create new tokens
    function mint(uint amount, address to) external onlyMinter {
        BEP20 token404 = BEP20(error404);
        if (to != address(this)) {
            token404.mint(amount);
            token404.transfer(to, amount);
            emit eventMintTokens(msg.sender, to, amount);
        }
    }

    // Check if it is an address with permission of minter
    function isMinter(address account) public view returns (bool) {
        if (IBEP20(error404).getOwner() != address(this)) {
            return false;
        }
        return _minters[account];
    }

    event eventSetMinter(address _minter, bool _canMint);
    event eventMintTokens(address indexed _minter, address indexed _to, uint _amount);
    event eventNewOwner(address _owner);
    
}