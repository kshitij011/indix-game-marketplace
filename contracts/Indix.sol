// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Indix is Initializable, PausableUpgradeable, OwnableUpgradeable, ERC1155URIStorageUpgradeable {

    uint256 public GAME_ID;
    uint256 totalGameKeys;

    // Token Id 1 reserved for gameKey, rest tokens for skins are incremented.
    uint256 totalSkinTypes = 1;

    uint256 public gameKeyPrice;
    address public GAME_DEVELOPER;

    struct Skin{
        string name;
        uint256 price;
    }

    struct RentListing {
        uint256 pricePerUnit;
        uint256 duration;      // seconds
        uint256 available;     // how many units owner is renting out
    }

    struct ActiveRent {
        address owner;
        uint256 amount;
        uint256 expiresAt;
    }

    // nested mapping incase if we want to list skins for sale or else we will need to create other mapping to get the owner.
    mapping(uint256 => mapping(address => Skin)) public skins;

    mapping(uint256 => mapping(address => RentListing)) public rentListings;
    mapping(uint256 => mapping(address => ActiveRent)) public activeRents;

    modifier onlyOwnerOrRenter(uint256 skinId) {
        if (balanceOf(msg.sender, skinId) > 0) return;

        ActiveRent memory rent = activeRents[skinId][msg.sender];
        require(rent.expiresAt > block.timestamp, "No usage rights");
        _;
    }

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

    // ---CORE LOGIC---
    function purchaseGameKey() public whenNotPaused payable {
        require(msg.value == gameKeyPrice, "Invalid price!");
        require(msg.sender != address(0), "Invalid account");
        require(totalGameKeys > 0, "Game keys exhausted!");

        _mint(msg.sender, 1, 1, "");
        totalGameKeys--;
    }

    function createSkin(string memory _name, uint256 _availableQuantity, uint256 _price, string memory _uri) public whenNotPaused returns(uint256){
        require(msg.sender == GAME_DEVELOPER, "You cannot create skin");

        totalSkinTypes++;
        skins[totalSkinTypes][GAME_DEVELOPER] = Skin(_name, _price);
        safeMint(GAME_DEVELOPER, totalSkinTypes, _availableQuantity, _uri);
        return totalSkinTypes;
    }

    function purchaseSkinFor(uint256 _skinId, address _to) public payable {
        require(_skinId > 1, "Can only purchase skins id's >= 2");
        require(_to != address(0), "Invalid recipient");
        require(msg.value == skins[_skinId][GAME_DEVELOPER].price, "Invalid skin price");
        require(balanceOf(GAME_DEVELOPER, _skinId) > 0, "Token doesn't exist or out of stock!");

        skins[_skinId][_to].price = msg.value;
        safeTransferFrom(GAME_DEVELOPER, _to, _skinId, 1, "");

        // platform fee is 1 %
        uint256 platformFee = (msg.value * 1) / 100;
        uint256 developerProfit = msg.value - platformFee;

        (bool sucess, ) = GAME_DEVELOPER.call{value: developerProfit}("");
        require(sucess, "Transfer failed");

    }

    function increaseTotalGameKeys(uint256 _amount) public whenNotPaused {
        require(msg.sender == GAME_DEVELOPER, "You cannot increase keys cap");
        require(_amount > 0, "amount 0");
        totalGameKeys += _amount;
    }

    function quantityAvailable(uint256 _skinId, address _address) public view returns(uint256){
        require(_skinId > 1, "TokenId not skin!");
        return balanceOf(_address, _skinId);
    }

    // ---RENTING PART---
    function listForRent(
        uint256 skinId,
        uint256 quantity,
        uint256 pricePerUnit,
        uint256 duration
    ) external {
        require(balanceOf(msg.sender, skinId) >= quantity, "Insufficient balance");
        require(quantity > 0 && pricePerUnit > 0 && duration > 0, "Invalid params");

        rentListings[skinId][msg.sender] = RentListing({
            pricePerUnit: pricePerUnit,
            duration: duration,
            available: quantity
        });
    }

    function unlistFromRent(uint256 skinId) external {
        delete rentListings[skinId][msg.sender];
    }

    function rentSkin(
        uint256 skinId,
        address owner,
        uint256 amount
    ) external payable {
        RentListing storage listing = rentListings[skinId][owner];

        require(listing.available >= amount, "Not enough listed");
        require(balanceOf(owner, skinId) >= amount, "Owner balance changed");

        uint256 totalPrice = listing.pricePerUnit * amount;
        require(msg.value == totalPrice, "Incorrect payment");

        // fees
        uint256 platformFee = (msg.value * 2) / 100;
        uint256 developerRoyalty = (msg.value * 3) / 100;
        uint256 ownerProfit = msg.value - platformFee - developerRoyalty;

        payable(GAME_DEVELOPER).transfer(developerRoyalty);
        payable(owner).transfer(ownerProfit);

        listing.available -= amount;

        activeRents[skinId][msg.sender] = ActiveRent({
            owner: owner,
            amount: amount,
            expiresAt: block.timestamp + listing.duration
        });
    }

    // Check rental validity
    function isRented(uint256 skinId, address user) public view returns (bool) {
        return activeRents[skinId][user].expiresAt > block.timestamp;
    }

    // Clearing epired rentals
    function clearExpiredRent(uint256 skinId) external {
        ActiveRent storage rent = activeRents[skinId][msg.sender];
        require(rent.expiresAt <= block.timestamp, "Still active");

        delete activeRents[skinId][msg.sender];
    }

    // ---OTHER FUNCTIONS---
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

    // users cannot set approvals to other users, only those who have purchased it has the control.
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(false,"Cannot set approval");
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) public virtual override{
        ActiveRent memory rent = activeRents[id][from];

        uint256 locked = 0;

        if(rent.expiresAt > block.timestamp){
            locked = rent.amount;
        }

        require(balanceOf(from, id) - locked >= value,"Insufficient transferable balance");

        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) {
            revert ERC1155MissingApprovalForAll(sender, from);
        }
        _safeTransferFrom(from, to, id, value, data);
    }

    // users cannot transfer the skins to other users.
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