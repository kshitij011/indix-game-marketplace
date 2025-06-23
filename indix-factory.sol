// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./Indix.sol";

contract IndixFactory {

    // Indix immutable index;
    uint256 totalGames;
    
    struct Game{
        string name;
        address deployedAddress;
        address owner;
    }

    mapping(uint256 => Game) public games;
    mapping(address => uint256[]) private gamesOwned;
    mapping(address => uint256) private lockedFunds;
    mapping(address => bool) private luckyWinner;

    // Convert to USD
    function lockFunds() external payable {
        require(msg.value == 0.1 ether, "Invalid amount");
        lockedFunds[msg.sender] = 0.1 ether;

        // unpause contract functions if developer locks funds again
        uint[] memory ownedGames = getOwnedGames(msg.sender);
        if(ownedGames.length > 0){

            for (uint256 i = 0; i < ownedGames.length; i++)
            {
                uint256 gameId = ownedGames[i];
                Game storage game = games[gameId];
                Indix(game.deployedAddress).unpause();
            }
        }
    }

    function registerGame(string calldata _gameName, uint256 _gameKeyPrice) public {
        require(lockedFunds[msg.sender] > 0, "Lock funds before registration!");
        totalGames++;
        Indix game = new Indix(totalGames, msg.sender, _gameKeyPrice);
        games[totalGames] = Game(_gameName, address(game), msg.sender);
        gamesOwned[msg.sender].push(totalGames);
    }

    function getGameAddress(uint256 _gameId) external view returns(address){
        return games[_gameId].deployedAddress;
    }

    function withdraw() external {
        require(lockedFunds[msg.sender] > 0, "Insufficient fund!");
        uint amount = lockedFunds[msg.sender];
        lockedFunds[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed!");

        // pause contract functions like mint if developer withdraws
        uint[] memory ownedGames = getOwnedGames(msg.sender);

        for (uint256 i = 0; i < ownedGames.length; i++)
        {
            uint256 gameId = ownedGames[i];
            Game storage game = games[gameId];
            Indix(game.deployedAddress).pause();
        }
    }

    function getOwnedGames(address _dev) public view returns(uint[] memory) {
        return gamesOwned[_dev];
    }

    function openCrate() public {
        // function to get random number from chainlinkVRF
        uint256 luckyNumber;
        if(block.timestamp % luckyNumber == 77) {
            luckyWinner[msg.sender] = true;
        }
    }

    function claimReward(uint256 _gameId, uint256 _skinId) public {
        require(_gameId > totalGames, "Game doesn't exist!");
        address gameContract = games[_gameId].deployedAddress;
        address gameDeveloper = games[_gameId].owner;

        // uint256 skinQuantity = Indix(gameContract).quantityAvailable(_skinId, gameDeveloper);
        (
        ,
        uint256 availableQuantity,
        ,
        uint256 price
        ) = Indix(gameContract).skins(_skinId, gameDeveloper);
        require(availableQuantity > 1, "Insufficient quantity");
        require(price <= 0.01 ether, "Price too high");

        Indix(gameContract).purchaseSkin{value: price}(_skinId, msg.sender);
    }
}

// 100000000000000000
