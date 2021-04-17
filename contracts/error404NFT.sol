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

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libs/IHelper.sol";

contract error404NFT is ERC721, Ownable {

    using SafeMath for uint256;

    IERC20 public token; // 404 Token Address
    uint256 public lastId; // Last NFT id created
    address dead = 0x000000000000000000000000000000000000dEaD; // Address Burn

    // Structure of the NFTs
    struct PathStruct {
        bool isExist;
        uint256 id;
        uint256 price;
    }
    mapping(uint => PathStruct) public paths; // List of NFTs
    mapping(address => mapping(uint => uint)) public tokensUser; // User NFTs
    uint256 public lastIdPath; // Last NFT id created

    constructor(IERC20 _token, string memory _name, string memory _alias) public ERC721(_name, _alias) {
        token = _token;
        _newNFT(0);
        lastId = 1;
    }

    // Internal function to create a new nft
    function _newNFT(uint256 _price) internal {
        PathStruct memory Path_Struct;
        Path_Struct = PathStruct({
            isExist: true,
            id: lastIdPath,
            price: _price
        });
        paths[lastIdPath] = Path_Struct;
        lastIdPath++;
    }

    // Function to create new NFTs
    function newNFT(uint256 _price) onlyOwner external {
        _newNFT(_price);
        emit eventNewNFT(_price);
    }

    // Update the price of an NFT
    function updatePrice(uint256 _price, uint256 _id) onlyOwner external {
        require(paths[_id].isExist == true, "!isExist");
        paths[_id].price = _price;
        emit eventUpdatePrice(_price, _id);
    }    

    // Update the price of all NFTs
    function updatePriceAll(uint256 _price) onlyOwner external {
        for (uint i = 0; i < lastIdPath; i++) {
            paths[i].price = _price;
        }
        emit eventUpdatePriceAll(_price);
    }

    // Buy an NFT with 404, 404 tokens are burned
    function buy(uint _id) external {
        require(_id > 0, "!id");
        require(paths[_id].isExist == true, "!isExist");
        require(token.transferFrom(msg.sender, address(this), paths[_id].price) == true, "You have not approved the deposit");
        _mint(msg.sender, lastId);
        token.transfer(dead, paths[_id].price);
        tokensUser[msg.sender][_id] = lastId;
        lastId++;
    }

    // Get the list of NTFs tokens purchased by a user
    function getNFTsUser(address _user) public view returns (bool[] memory) {
        bool[] memory parentTokens = new bool[](lastIdPath);
        for (uint i = 0; i < lastIdPath; i++) {
            parentTokens[i] = checkNFT(_user, i);
        }
        return parentTokens;
    }

    // Check if an NFT belongs to a user
    function checkNFT(address _user, uint _id) public view returns (bool) {
        if(ownerOf(tokensUser[_user][_id]) == _user){
            return true;
        } else {
            return false;
        }
    }

    event eventUpdatePrice(uint256 _price, uint256 _id);
    event eventUpdatePriceAll(uint256 _price);
    event eventNewNFT(uint256 _price);
    
}