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
import "./libs/IHelper.sol";

contract error404Lottery {

    using SafeMath for uint256;

    IERC20 public token; // 404 Token Address
    IERC721 public nft; // 404 NFT Address
    uint256 public turns = 10; // Shifts that a user can buy per round
    uint public lastRound; // Last round
    uint256[3] public gainPercent = [70, 20, 10]; // Winner Percentages
    uint256 public dateEnd = now + 1 days; // End date of the round
    address public dev; // Dev Address
    
    // Rounds structure
    struct RoundStruct {
        bool isExist;
        bool turn;
        uint id;
        uint start;
        uint finish;
        uint totalParticipants;
        uint256 amount;
    }
    mapping(uint => RoundStruct) public Rounds; // List of rounds
    mapping(uint => mapping (uint => address)) public RoundsParticipants; // List of participants per round
    mapping(uint => mapping (address => uint)) public ParticipantsTurns; // List of purchased shifts of participants per round
    mapping(address => uint) public unclaimedTokens; // List of unclaimed tokens from non-winning users per round
    uint256 public unclaimed; // Unclaimed Total
    mapping(uint => mapping (uint => address)) public winners; // List of winners per round

    constructor(IERC20 _token, IERC721 _nft, address _dev) public {
        token = _token;
        nft = _nft;
        dev = _dev;
    }

    // Function to play in the lottery, the user chooses how many turns he wants to buy, the maximum number of turns is 10
    function Game(uint _turns) external returns (bool) {
        require(now < dateEnd, "must end game for you to play");
        require(Rounds[lastRound].turn == false, "The game is over");
        require(_turns <= turns, "You can't buy so many shifts");
        require((checkTurns() + _turns) <= turns, "You can't buy so many shifts");
        require(nft.balanceOf(msg.sender) >= 2, "You don't have 2 nft tokens to play");
        require(token.balanceOf(msg.sender) >= _turns.mul(10 ** 18), "You do not have the amount of tokens to deposit");
        require(token.transferFrom(msg.sender, address(this), _turns.mul(10 ** 18)) == true, "You have not approved the deposit");
        if( Rounds[lastRound].isExist == false ){
            RoundStruct memory round_struct;
            round_struct = RoundStruct({
                isExist: true,
                turn: false,
                id: lastRound,
                start: now,
                finish: 0,
                totalParticipants: 0,
                amount: 0
            });
            Rounds[lastRound] = round_struct;
            dateEnd = now + 1 days;
        }
        unclaimed = unclaimed.add(_turns.mul(10 ** 18));
        for(uint i = 1; i<=_turns; i++){
            RoundsParticipants[lastRound][Rounds[lastRound].totalParticipants] = msg.sender;
            Rounds[lastRound].totalParticipants++;
            ParticipantsTurns[lastRound][msg.sender]++;
        }
        return true;
    }

    // Function that is executed 1 day after a round starts, if it has more than 6 participants the game is ended, otherwise the date is updated 1 more day to the current round
    function Finish() external {
        require(now > dateEnd, "the game is not over yet");
        if(Rounds[lastRound].totalParticipants <= 6){
            dateEnd = now + 1 days;
        } else {
            require(nft.balanceOf(msg.sender) >= 2, "You don't have 2 nft tokens to play");
            if(token.balanceOf(address(this)) > 0){
                uint256 balance_ref = (token.balanceOf(address(this))).sub(unclaimed);
                token.transfer(dev, balance_ref.mul(9).div(100));
                token.transfer(msg.sender, balance_ref.mul(1).div(100));
                uint256 balance = (token.balanceOf(address(this))).sub(unclaimed);
                Rounds[lastRound].amount = balance;
                uint count = 0;
                uint x = 1;
                while(x <= 3){
                    count++;
                    address _userCheck = RoundsParticipants[lastRound][randomness(count)];
                    if(_userCheck != address(0)){
                        winners[lastRound][x] = _userCheck;
                        uint256 percentage = getPercentage(x);
                        uint256 amount = (balance.mul(percentage)).div(100);
                        token.transfer(_userCheck, amount);
                        x++;
                    }
                }
            }
            for(uint i = 0; i<=Rounds[lastRound].totalParticipants; i++){
                unclaimedTokens[RoundsParticipants[lastRound][i]] = ParticipantsTurns[lastRound][RoundsParticipants[lastRound][i]] * (10 ** 18);
            }
            Rounds[lastRound].finish = now;
            lastRound++;
            dateEnd = now + 1 days;
        }
    }

    // Claiming tokens from non-winning users
    function claim() public {
        require(unclaimedTokens[msg.sender] > 0, "you don't have tokens to claim");
        token.transfer(msg.sender, unclaimedTokens[msg.sender]);
        unclaimed = unclaimed.sub(unclaimedTokens[msg.sender]);
        unclaimedTokens[msg.sender] = 0;
    }

    // function that generates a random number
    function randomness(uint nonce) public view returns (uint) {
        return uint(uint(keccak256(abi.encode(block.timestamp, block.difficulty, nonce)))%(Rounds[lastRound].totalParticipants+1));
    }

    // Get the percentage of a position to win
    function getPercentage(uint x) public view returns (uint256){
        if(x == 1){return gainPercent[0];}
        else if(x == 2){return gainPercent[1];}
        else if(x == 3){return gainPercent[2];}
    }    

    // Check how many shifts a user has bought in the last round
    function checkTurns() public view returns(uint){
        return ParticipantsTurns[lastRound][msg.sender];
    }

    // 404 Lottery Balance Minus Total Unclaimed Tokens
    function balanceWin() public view returns (uint256) {
        return (token.balanceOf(address(this))).sub(unclaimed);
    }

}