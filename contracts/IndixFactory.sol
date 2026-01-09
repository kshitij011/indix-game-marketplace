// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IIndix} from "./interfaces/IIndix.sol";

contract IndixFactory is Ownable, ReentrancyGuard{

    using Clones for address;
    uint256 public totalGames;

    address public indixBlueprint;
    uint256 public constant MAX_GAMES_PER_PUBLISHER = 100;
    uint256 public constant STAKE_AMOUNT = 0.1 ether;

    struct Game{
        string name;
        address deployedAddress;
        address owner;
    }

    mapping(uint256 => Game) public games;
    mapping(address => uint256[]) private gamesOwned;
    mapping(address => uint256) public lockedFunds;
    mapping(address => bool) private luckyWinner;

    event FundsLocked(address indexed publisher, uint amount);
    event GameRegistered(address indexed publisher, uint indexed _gameId, address indexed _gameAddress, string _gameName);
    event Withdrawn(address indexed publisher, uint amount);
    event BlueprintUpdated(address oldImpl, address newImpl);

    constructor(address _blueprint) Ownable(msg.sender) {
        require(_blueprint != address(0), "Invalid blueprint");
        indixBlueprint = _blueprint;
    }

    function lockFunds() external payable  nonReentrant{
        require(msg.value == STAKE_AMOUNT, "Invalid amount");
        lockedFunds[msg.sender] = STAKE_AMOUNT;
        emit FundsLocked(msg.sender, STAKE_AMOUNT);

        _unpauseOwnedGames(msg.sender);
    }

    function registerGame(string calldata _gameName, uint256 _gameKeyPrice) public {
        require(lockedFunds[msg.sender] == STAKE_AMOUNT, "STAKE_REQUIRED!");
        if(gamesOwned[msg.sender].length == MAX_GAMES_PER_PUBLISHER) {
            revert ("Max limit reached, consider releasing from other account.");
        }
        totalGames++;
        address clone = indixBlueprint.clone();

        IIndix(clone).initialize(totalGames, msg.sender, _gameKeyPrice);

        games[totalGames] = Game({
            name: _gameName,
            deployedAddress: clone,
            owner: msg.sender
        });
        gamesOwned[msg.sender].push(totalGames);

        emit GameRegistered(msg.sender, totalGames, clone, _gameName);
    }

    function withdrawStake() external nonReentrant{
        uint amount = lockedFunds[msg.sender];
        require(amount> 0, "Insufficient fund!");
        lockedFunds[msg.sender] = 0;

        _pauseOwnedGames(msg.sender);
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed!");

        emit Withdrawn(msg.sender, amount);
    }

    function openCrate() public {
        // function to get random number from chainlinkVRF (will be implemented soon)
        revert("feature coming soon!");
        uint256 luckyNumber;
        if(block.timestamp % luckyNumber == 77) {
            luckyWinner[msg.sender] = true;
        }
    }

    function claimReward(uint256 _gameId, uint256 _skinId) public {
        require(_gameId > 0 && _gameId <= totalGames, "Game doesn't exist!");
        require(luckyWinner[msg.sender] == true, "Cannot claim");
        address gameContract = games[_gameId].deployedAddress;
        address gameDeveloper = games[_gameId].owner;

        (
        ,
        uint256 availableQuantity,
        ,
        uint256 price
        ) = IIndix(gameContract).skins(_skinId, gameDeveloper);
        require(availableQuantity > 1, "Insufficient quantity");
        require(price <= 0.01 ether, "Price too high");

        IIndix(gameContract).purchaseSkin{value: price}(_skinId, msg.sender);
        luckyWinner[msg.sender] = false;
    }

    function updateBlueprint(address newBlueprint) external onlyOwner {
        require(newBlueprint != address(0), "Invalid blueprint");
        address old = indixBlueprint;
        indixBlueprint = newBlueprint;

        emit BlueprintUpdated(old, newBlueprint);
    }

    // VIEW FUNCTIONS
    function getGameAddress(uint256 _gameId) external view returns(address){
        return games[_gameId].deployedAddress;
    }

    function getOwnedGames(address _dev) public view returns(uint[] memory) {
        return gamesOwned[_dev];
    }

    // INTERNAL FUNCTIONS
    function _unpauseOwnedGames(address dev) internal {
        uint256[] memory ownedGames = gamesOwned[dev];
        for(uint256 i; i < ownedGames.length; i++) {
            uint256 gameId = ownedGames[i];
            Game storage game = games[gameId];
            IIndix(game.deployedAddress).unpause();
        }
    }

    function _pauseOwnedGames(address dev) internal {
        uint256[] memory ownedGames = gamesOwned[dev];
        for(uint256 i; i < ownedGames.length; i++){
            uint256 gameId = ownedGames[i];
            Game storage game = games[gameId];
            IIndix(game.deployedAddress).pause();
        }

    }
}