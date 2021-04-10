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

interface IReferrals {

    function isMember(address _user) external view returns (bool);

    function getListReferrals(address _member) external view returns (address[] memory);

    function addMember(address _member, address _parent) external;

    function getSponsor(address account) external view returns (address);

    function membersList(uint256 id) external view returns (address);

}