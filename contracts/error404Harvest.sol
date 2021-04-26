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
import "./libs/IChef.sol";
import "./libs/IHelper.sol";

contract error404Harvest {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // function to harvest all strategies
    function harvestAll(IChef[] calldata _chefs) external {
        uint256 _length =  _chefs.length;
        for (uint256 i = 0; i < _length; i++) {
            _chefs[i].harvestExternal(msg.sender);
        }
    }
    
}