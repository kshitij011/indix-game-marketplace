// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// contract Indix is Initializable, Pausable, Ownable(msg.sender), ERC1155(""), ERC1155URIStorage{
contract Indix is Initializable, PausableUpgradeable, OwnableUpgradeable, ERC1155URIStorageUpgradeable {


    uint256 public GAME_ID;
    uint256 gameIdCap;
    uint256 totalTokens = 1;

    uint256 public gameKeyPrice;
    address public GAME_DEVELOPER;

    struct Skin{
        string name;
        uint256 availableQuantity;
        address owner;
        uint256 price;
    }

    struct ListForRent {
        uint256 quantity;
        uint256 price;
    }

    // nested mapping incase if we want to list skins for sale or else we will need to create other mapping to get the owner.
    mapping(uint256 => mapping(address => Skin)) public skins;

    mapping(address => mapping(uint256 => ListForRent)) public listedForRent;
    // mapping(uint256 => Skin) public skins;
    mapping(address => uint256) public rentDeadline;

    // checks if a SkinId is rented/lended from _from address to _to address
    // mapping(uint256 => mapping(address => mapping(address => bool))) rentedTo;
    mapping(uint256 => mapping(address => mapping(address => bool))) lendedTo;
    mapping(address => uint256) rentedAmount;
    mapping(uint256 => mapping(address => bool)) rented;

    function initialize(uint256 _gameId, address _gameDeveloper, uint256 _keyPrice)external initializer {
        GAME_ID = _gameId;
        GAME_DEVELOPER = _gameDeveloper;
        gameKeyPrice = _keyPrice;

        __ERC1155_init("");
        __Ownable_init(msg.sender);
        __Pausable_init();
    }

    function setURI(string memory newuri) external {
        require(msg.sender == GAME_DEVELOPER, "You cannot create skin");
        _setURI(newuri);
    }

    function purchaseGameKey() public whenNotPaused payable {
        require(msg.value == gameKeyPrice, "Invalid price!");
        require(msg.sender != address(0), "Invalid account");
        require(gameIdCap > 0, "GameId's exhausted!");

        _mint(msg.sender, 1, 1, "");
        gameIdCap--;
    }

    function createSkin(string memory _name, uint256 _availableQuantity, uint256 _price, string memory _uri) public whenNotPaused returns(uint256){
        require(msg.sender == GAME_DEVELOPER, "You cannot create skin");

        totalTokens++;
        skins[totalTokens][GAME_DEVELOPER] = Skin(_name, _availableQuantity, GAME_DEVELOPER, _price);
        // skins[totalTokens] = Skin(_name, _availableQuantity, GAME_DEVELOPER, _price);
        // _mint(GAME_DEVELOPER, totalTokens, _availableQuantity, "");
        safeMint(GAME_DEVELOPER, totalTokens, _availableQuantity, _uri);
        return totalTokens;
    }

    function purchaseSkin(uint256 _skinId, address _to) public payable {
        require(msg.value == skins[_skinId][GAME_DEVELOPER].price, "Invalid skin price");
        // require(msg.value == skins[_skinId].price);
        require(skins[_skinId][GAME_DEVELOPER].availableQuantity > 1, "Token doesn't exist!");
        // require(skins[_skinId].availableQuantity > 1, "Skins exhausted!");
        require(_skinId > 1, "Cannot purchase");

        // skins[_skinId][GAME_DEVELOPER].availableQuantity--;
        skins[_skinId][GAME_DEVELOPER].availableQuantity--;

        uint256 buyerBalance = skins[_skinId][_to].availableQuantity++;
        skins[_skinId][_to] = Skin(skins[_skinId][GAME_DEVELOPER].name, buyerBalance, _to, 0);
        safeTransferFrom(skins[_skinId][GAME_DEVELOPER].owner, _to, _skinId, 1, "");

        uint256 platformFee = (msg.value * 1) / 100;
        uint256 developerProfit = msg.value - platformFee;

        (bool sucess, ) = GAME_DEVELOPER.call{value: developerProfit}("");
        require(sucess, "Transfer failed");

    }

    function increaseGameIdCap(uint256 _amount) public whenNotPaused {
        require(msg.sender == GAME_DEVELOPER, "You cannot increase keys cap");
        gameIdCap += _amount;
    }

    function quantityAvailable(uint256 _skinId, address _address) public view returns(uint256){
        require(_skinId > 1, "TokenId not skin!");
        return skins[_skinId][_address].availableQuantity;
    }

    // function rentSkin(uint256 _skinId, address _skinOwner) public payable {
    //     require(msg.value == 0.001 ether);
    //     require(!rentedTo[_skinId][GAME_DEVELOPER][msg.sender], "Skin already rented");
    //     require(!lendedTo[_skinId][GAME_DEVELOPER][msg.sender], "Skin already lended");

    //     uint256 platformFee = (msg.value * 2) / 100;
    //     uint256 developerRoyalty = (msg.value * 3) / 100;
    //     uint256 skinOwnerProfit = msg.value - (platformFee + developerRoyalty);

    //     (bool success, ) = GAME_DEVELOPER.call{value: developerRoyalty}("");
    //     require(success, "Transfer failed");

    //     (bool success2, ) = skins[_skinId][_skinOwner].owner.call{value: skinOwnerProfit}("");
    //     require(success2, "Transfer failed");

    //     rentDeadline[msg.sender] = block.timestamp + 1 weeks;
    //     // safeTransferFrom(skins[_skinId][GAME_DEVELOPER].owner, msg.sender, _skinId, 1, "");
    //     rentedTo[_skinId][GAME_DEVELOPER][msg.sender] = true;
    // }

    function unlistFromRent(uint256 _skinId, uint _quantity) external {
        require(listedForRent[msg.sender][_skinId].quantity > 0, "No NFT's to unlist!");
        listedForRent[msg.sender][_skinId].quantity -= _quantity;
    }

    function listForRent(uint256 _skinId, uint256 _quantity, uint256 _price) external {
        require(balanceOf(msg.sender, _skinId) > 1, "Not enough balance");
        require(listedForRent[msg.sender][_skinId].quantity > 0, "No NFT's to unlist!");
        listedForRent[msg.sender][_skinId] = ListForRent(_quantity, _price);
    }

    function rentSkin(uint256 _skinId, address _skinOwner) public payable {
        require(msg.value == listedForRent[_skinOwner][_skinId].price, "Pay listed price");

        rented[_skinId][msg.sender] = true;

        uint256 platformFee = (msg.value * 2) / 100;
        uint256 developerRoyalty = (msg.value * 3) / 100;
        uint256 skinOwnerProfit = msg.value - (platformFee + developerRoyalty);

        (bool success, ) = GAME_DEVELOPER.call{value: developerRoyalty}("");
        require(success, "Transfer failed");

        (bool success2, ) = skins[_skinId][_skinOwner].owner.call{value: skinOwnerProfit}("");
        require(success2, "Transfer failed");

        rentDeadline[msg.sender] = block.timestamp + 1 weeks;
        safeTransferFrom(_skinOwner, msg.sender, _skinId, 1, "");
        // rentedTo[_skinId][GAME_DEVELOPER][msg.sender] = true;
    }

    function rentTimeleft() public view returns(uint256){
        uint256 deadline = rentDeadline[msg.sender];
        uint256 timeLeft = deadline - block.timestamp;
        return timeLeft;
    }

    // function pullRentedSkin(address _from, uint _skinId) public{
    //     require(rentedTo[_skinId][GAME_DEVELOPER][msg.sender], "Skin not rented!");
    //     require(rentTimeleft() == 0, "Time's left to pull");
    //     require(skins[_skinId][msg.sender].owner == msg.sender, "You're not owner!");

    //     rentedTo[_skinId][GAME_DEVELOPER][msg.sender] = true;
    //     safeTransferFrom(_from, msg.sender, _skinId, 1, "");
    // }

    function pullRentedSkin(address _from, uint _skinId) public {
        require(rented[_skinId][_from], "Not rented");
        // require(rentedTo[_skinId][GAME_DEVELOPER][msg.sender], "Skin not rented!");
        require(rentTimeleft() == 0, "Time's left to pull");
        require(skins[_skinId][msg.sender].owner == msg.sender, "You're not owner!");

        // rentedTo[_skinId][GAME_DEVELOPER][msg.sender] = true;
        safeTransferFrom(_from, msg.sender, _skinId, 1, "");
    }

    // lend without any funds
    // function lendSkin(uint256 _skinId) public {
    //     // require(msg.value == 0.001 ether);
    //     require(!rentedTo[_skinId][GAME_DEVELOPER][msg.sender], "Skin already rented");
    //     // rentDeadline[msg.sender] = block.timestamp + 1 weeks;
    //     // safeTransferFrom(skins[_skinId][GAME_DEVELOPER].owner, msg.sender, _skinId, 1, "");
    //     lendedTo[_skinId][GAME_DEVELOPER][msg.sender] = true;
    // }

    // function pullLendedSkin(uint256 _skinId) public {
    //     require(lendedTo[_skinId][GAME_DEVELOPER][msg.sender], "Skin not lended");
    //     lendedTo[_skinId][GAME_DEVELOPER][msg.sender] = false;
    // }

    // only owner (IndixFactory can pause / unpause)
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    function setBaseURI() internal virtual {
        _setBaseURI("cyan-realistic-swift-995.mypinata.cloud/ipfs/");
    }

    function safeMint(address _to, uint256 _skinId, uint256 _availableQuantity, string memory _uri) internal {
        _mint(_to, _skinId, _availableQuantity, "");
        _setURI(_skinId, _uri);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(false,"Cannot set approval");
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual override{
        require(rented[id][msg.sender], "NFT is rented cannot transfer");
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeTransferFrom(from, to, id, value, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override {
        require(false, "cannot batchtransfer for now");
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeBatchTransferFrom(from, to, ids, values, data);
    }
}