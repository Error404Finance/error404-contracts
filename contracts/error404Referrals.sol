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
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract error404Referrals is Ownable {

    struct MemberStruct {
        bool isExist;
        uint256 id;
        uint256 referrerID;
        uint256 referredUsers;
        uint256 time;
    }
    mapping(address => MemberStruct) public members; // Membership structure
    mapping(uint256 => address) public membersList; // Member listing by id
    mapping(uint256 => mapping(uint256 => address)) public memberChild; // List of referrals by user
    uint256 public lastMember; // ID of the last registered member
    mapping(address => bool) private _mods; // List Mods

    // Only mods
    modifier onlyMod {
        require(isMod(msg.sender) == true, "error404Referrals: caller is not the mod");
        _;
    }

    // Add and remove a moe
    function setMod(address mod, bool canMod) external onlyOwner {
        if (canMod) {
            _mods[mod] = canMod;
        } else {
            delete _mods[mod];
        }
        emit eventSetMod(mod, canMod);
    }

    // Only moderators can register new users
    function addMember(address _member, address _parent) public onlyMod {
        if (lastMember > 0) {
            require(members[_parent].isExist, "Sponsor not exist");
        }
        MemberStruct memory memberStruct;
        memberStruct = MemberStruct({
            isExist: true,
            id: lastMember,
            referrerID: members[_parent].id,
            referredUsers: 0,
            time: now
        });
        members[_member] = memberStruct;
        membersList[lastMember] = _member;
        memberChild[members[_parent].id][members[_parent].referredUsers] = _member;
        members[_parent].referredUsers++;
        lastMember++;
        emit eventNewUser(msg.sender, _member, _parent);
    }

    // Returns the list of referrals
    function getParentTree(address _member) public view returns (address[] memory){
        address[] memory parentTree = new address[](members[_member].referredUsers);
        address referrerLevel = membersList[members[_member].referrerID];
        if (referrerLevel != address(0)) {
            parentTree[0] = referrerLevel;
        }
        for (uint256 i = 1; i < members[_member].referredUsers; i++) {
            if (referrerLevel != address(0)) {
                referrerLevel = membersList[members[referrerLevel].referrerID];
                if (referrerLevel != address(0)) {
                    parentTree[i] = referrerLevel;
                }
            } else {
                break;
            }
        }
        return parentTree;
    }

    // Check if it is an address with permission of mod
    function isMod(address account) public view returns (bool) {
        return _mods[account];
    }

    // Check if an address is registered
    function isMember(address _user) public view returns (bool) {
        return members[_user].isExist;
    }    

    event eventSetMod(address _mod, bool _canMod);
    event eventNewUser(address _mod, address _member, address _parent);

}