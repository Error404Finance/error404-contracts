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

interface IHelper {

    function harvestAll() external;

    function harvest(uint256 _start, uint256 _end) external;

    function temporalBytecode() external;

    function importProfit(uint256 _amount) external;

    function getFactory() external view returns(address);
    
    function getRouter() external view returns(address);

    function depositZap(address _user, uint256 _amount, address _sponsor) external;
    
}