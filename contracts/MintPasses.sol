//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./MintPassRarityGenerator.sol";

// We import this library to be able to use console.log
import "hardhat/console.sol";

// This is the main building block for smart contracts.
contract MintPasses is Context, ERC721Enumerable, Ownable, ReentrancyGuard, MintPassRarityGenerator {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;
    uint256 public totalBidsLimit;
    uint256 public totalBids; // Not used
    uint256 public latestBidId = 1;
    uint256 public start;
    uint256 public minimumBidAmount;
    uint256 public auctionDuration;
    bool public active;
    address public scionContract;
    address public treasury;

    bytes32 public constant BRONZE = keccak256("BRONZE");
    bytes32 public constant SILVER = keccak256("SILVER");
    bytes32 public constant GOLD = keccak256("GOLD");
    bytes32 public constant PLATINUM = keccak256("PLATINUM");
    bytes32 public constant RUBY = keccak256("RUBY");
    bytes32 public constant ONYX = keccak256("ONYX");

    mapping (uint256 => Bid) public bids;
    mapping (address => uint256[]) public userBidIds;
    mapping (address => mapping (uint256 => uint256)) public userBidIndexes;
    mapping (address => mapping (uint256 => uint256)) public bidIndexes;
    mapping (uint256 => bytes32) public mintingPassClass;
    mapping (uint256 => uint256) public mintingPassRandom;
    mapping (address => bool) public userClaimed;

    // mapping (uint256 => Rarity) public tokenRarity; // Could be done like this
    struct MintPass {
        bool claimed;
        bool receives;
    }

    struct Class {
        uint256 bottom;
        uint256 top;
        uint256 timestamp;
    }

    mapping(bytes32 => Class) public classes;
    mapping(address => MintPass) public promotionPasses;
    address[] public promotionMintingAddresses;

    Bid[] bidsArray;

    struct Bid {
        uint256 id;
        uint256 bidValue;
        address bidder;
        uint256 timestamp;
    }

    event BidPlaced(address indexed bidder, uint256 indexed amount, uint256 indexed bidId, uint256 timestamp);
    event BidCanceled(address indexed bidder, uint256 indexed amount, uint256 indexed bidId, uint256 timestamp);
    event BidUpdated(address indexed bidder, uint256 previousAmount, uint256 indexed amount, uint256 indexed bidId, uint256 timestamp);
    event PassClaimed(address indexed bidder, uint256 indexed passId, uint256 indexed bidId, uint256 timestamp);

    modifier onlyActive() {
        require(active && (block.timestamp > start && block.timestamp < start + auctionDuration), "Inactive");
        _;
    }

    modifier onlyWhenFinished() {
        require(active && (block.timestamp > start + auctionDuration), "Auction inactive or hasn't finish yet");
        _;
    }

    /**
     * See {ERC721-tokenURI}.
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint256 _totalBidsLimit,
        uint256 _minimumBidAmount,
        uint256 _start, // Not being used
        uint256 _auctionDuration,
        uint64 subscriptionId,
        address vrfCoordinator,
        address link,
        bytes32 _keyHash
    )
        // TODO assert non empty treasury
        ERC721(name, symbol)
        MintPassRarityGenerator(subscriptionId, vrfCoordinator, link, _keyHash) {
        // uint64 subscriptionId, address vrfCoordinator, address link, bytes32 _keyHash
        _baseTokenURI = baseTokenURI;
        totalBidsLimit = _totalBidsLimit;
        //start = block.timestamp;
        auctionDuration = _auctionDuration;
        minimumBidAmount = _minimumBidAmount;
    }

    function isAuctionFinished() public view returns (bool) {
        return block.timestamp > start + auctionDuration;
    }

    function getAllBids() public view returns (Bid[] memory) {
        return bidsArray;
    }

    function getUserBidIds(address _address) public view returns (uint256[] memory) {
        return userBidIds[_address];
    }

    function getBidClass(uint256 _bidId) public view returns (bytes32) {
        uint256 bidValue = bids[_bidId].bidValue;

        if(bidValue < classes[BRONZE].bottom) {
            return 0x00;
        }

        if(bidValue < classes[BRONZE].top) {
            return BRONZE;
        } else if(bidValue >= classes[SILVER].bottom && bidValue < classes[SILVER].top) {
            return SILVER;
        } else if(bidValue >= classes[GOLD].bottom && bidValue < classes[GOLD].top) {
            return GOLD;
        } else if(bidValue >= classes[PLATINUM].bottom && bidValue < classes[PLATINUM].top) {
            return PLATINUM;
        } else if(bidValue >= classes[RUBY].bottom && bidValue < classes[RUBY].top) {
            return RUBY;
        } else if(bidValue >= classes[ONYX].bottom && bidValue < classes[ONYX].top) {
            return ONYX;
        }
    }

    function getBidsClasses() public view returns (bytes32[] memory) {
       bytes32[] memory result = new bytes32[](userBidIds[_msgSender()].length);

       for(uint y = 0; y < userBidIds[_msgSender()].length; y++) {
            result[y] = getBidClass(userBidIds[_msgSender()][y]);
       }

       return result;
    }

    function setClasses(bytes32[] memory _class, uint256[] memory _bottom, uint256[] memory _top, uint256[] memory _timestamp) public {
        require(_class.length == _bottom.length && _bottom.length == _top.length && _top.length == _timestamp.length);
        for(uint i = 0; i < _class.length; i++) {
            setClass(_class[i], _bottom[i], _top[i], _timestamp[i]);
        }
    }

    function setClass(bytes32 _class, uint256 _bottom, uint256 _top, uint256 _timestamp) public onlyOwner {
        classes[_class] = Class(_bottom, _top, _timestamp);
    }

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setTotalLimit(uint256 _totalBidsLimit) external onlyOwner {
        totalBidsLimit = _totalBidsLimit;
    }

    function setScionAddress(address _scionContract) external onlyOwner {
        scionContract = _scionContract;
    }

    function setStart(uint256 _auctionDuration, uint256 _auctionStart) external onlyOwner {
        active = true;
        start = _auctionStart;
        auctionDuration = _auctionDuration * 1 minutes;
    }

    function finishAuction() external onlyOwner {
        auctionDuration = block.timestamp > start ? block.timestamp - start : 0;
    }

    function setActive(bool _active) external onlyOwner {
        active = _active;
    }

    function baseURI() public view returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function userAvailableToClaim(address _address) public view returns(uint256) {
        uint256 result;

        for(uint i = 0; i < userBidIds[_address].length; i++) {
            if(getBidClass(userBidIds[_address][i]) != 0x00) {
                result++;
            }
        }

        return result;
    }

    function random(uint _tokenId) internal view returns(uint){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty,
        msg.sender, _tokenId))) % 1000;
    }

    function claimPass() external onlyWhenFinished {
        // This assumes that the auction overpassed the total bids limit
        require(!userClaimed[_msgSender()], "User already claimed");
        require(userBidIds[_msgSender()].length > 0 && userAvailableToClaim(_msgSender()) > 0 , "User didn't win an auction");

        // A user could have thousands of bids, may provoke a gas problem here
        for(uint i = 0; i < userBidIds[_msgSender()].length; i++) {
            if(bids[userBidIds[_msgSender()][i]].bidValue > 0 && getBidClass(userBidIds[_msgSender()][i]) != 0x00) {
                mintingPassClass[_tokenIdTracker.current()] = getBidClass(userBidIds[_msgSender()][i]);
                mintingPassRandom[_tokenIdTracker.current()] = random(_tokenIdTracker.current());
                payable(treasury).transfer(bids[userBidIds[_msgSender()][i]].bidValue);

                _safeMint(_msgSender(), _tokenIdTracker.current());

                _tokenIdTracker.increment();

                emit PassClaimed(_msgSender(), _tokenIdTracker.current() - 1, userBidIds[_msgSender()][i], block.timestamp);
            }
        }

        userClaimed[_msgSender()] = true;
    }

    function bid(uint bidsAmount, uint bidValue) external payable onlyActive nonReentrant {
        require(bidValue > minimumBidAmount, "Bid value must be bigger then minimum bid");
        require(msg.value >= bidValue * bidsAmount, "There is not enough funds to make bids");
        require(bidsAmount <= 30, "Too many bids during 1 transaction");

        for(uint i = 0; i < bidsAmount; i++) {
            bids[latestBidId] = Bid(latestBidId, bidValue, _msgSender(), block.timestamp);
            userBidIndexes[_msgSender()][latestBidId] = userBidIds[_msgSender()].length == 0 ? 0 : userBidIds[_msgSender()].length - 1;
            userBidIds[_msgSender()].push(latestBidId);

            bidIndexes[_msgSender()][latestBidId] = bidsArray.length == 0 ? 0 : bidsArray.length - 1;
            bidsArray.push(bids[latestBidId]);
            latestBidId++;

            emit BidPlaced(_msgSender(), bidValue, latestBidId - 1,  block.timestamp);
        }
    }

    function updateBid(uint bidId) external payable onlyActive nonReentrant {
        require(msg.value > 0, "There is not enough funds to update bid");
        require(_msgSender() == bids[bidId].bidder, "Not the owner of the bid");
        uint newBidValue = bids[bidId].bidValue + msg.value;

        emit BidUpdated(_msgSender(), bids[bidId].bidValue, newBidValue, bidId,  block.timestamp);
        bids[bidId] = Bid(bidId, newBidValue, _msgSender(), block.timestamp);
        bidsArray[bidIndexes[_msgSender()][bidId]] = bids[bidId];
    }

    function cancelBid(uint bidId) external nonReentrant {
        //TODO we should't allow canceling bid after the auction is over, even if no limits set
        require((block.timestamp > start && block.timestamp < start + auctionDuration) || (block.timestamp > start + auctionDuration && classes[BRONZE].top != 0 && getBidClass(bidId) == 0x00));
        require(_msgSender() == bids[bidId].bidder, "Not the owner of the bid");
        uint256 _bidValue = bids[bidId].bidValue;

        delete bids[bidId];

        userBidIds[_msgSender()][userBidIndexes[_msgSender()][bidId]] = userBidIds[_msgSender()][userBidIds[_msgSender()].length - 1];
        userBidIds[_msgSender()].pop();

        bidsArray[bidIndexes[_msgSender()][bidId]] = bidsArray[bidsArray.length - 1];
        bidsArray.pop();

        payable(_msgSender()).transfer(_bidValue);
        emit BidCanceled(_msgSender(), _bidValue, bidId, block.timestamp);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function addPromotionMintingAddress(address _beneficiary) public onlyOwner {
        promotionMintingAddresses.push(_beneficiary);
        promotionPasses[_beneficiary].receives = true;
    }

    function claimPromotionMintingPasses() public {
        // Auction already finish require here
        MintPass memory userPromotionPass = promotionPasses[_msgSender()];
        require(userPromotionPass.receives, 'MintPasses: invalid user');
        require(!userPromotionPass.claimed, 'MintPasses: user already claimed');

        _safeMint(_msgSender(), _tokenIdTracker.current());
        requestRandomWords(_tokenIdTracker.current()); // Sets the rarity
        _tokenIdTracker.increment();
        promotionPasses[_msgSender()].claimed = true;
    }

    function burn(uint256 tokenId) external {
        require(scionContract == _msgSender(), "Only scion contract can burn");
        _burn(tokenId);
    }
}
