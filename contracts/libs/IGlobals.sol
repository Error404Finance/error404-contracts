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

interface IGlobals {

    function token() external view returns (address);

    function nft() external view returns (address);

    function lottery() external view returns (address);

    function minter() external view returns (address);

    function referrals() external view returns (address);

    function devaddr() external view returns (address);

    function feeAddress() external view returns (address);

    function reward() external view returns (address);

    function rewardLottery() external view returns (uint256);

    function rewardSponsors() external view returns (uint256);

    function rewardDevs() external view returns (uint256);

    function feeDevs() external view returns (uint256);

    function BURN_RATE() external view returns (uint256);

    function paths(address _token, uint256 _id) external view returns (address[] memory);

    function getPaths(address _token, uint256 _id) external view returns(address[] memory);

    function token0() external view returns (address);

    function token1() external view returns (address);

}