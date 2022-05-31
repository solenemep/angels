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

    string private _baseTokenURI; // Not used
    uint256 public totalBidsLimit;
    uint256 public totalBids; // Not used
    uint256 public latestBidId = 1;
    uint256 public start;
    uint256 public auctionDuration;
    uint256 public lastBidAmount; //get the highest bid
    bool public active;
    address public scionContract;

    mapping (uint256 => Bid) public bids;
    mapping (address => uint256[]) public userBidIds;
    mapping (address => mapping (uint256 => uint256)) public userBidIndexes;
    mapping (address => mapping (uint256 => uint256)) public bidIndexes;

    // mapping (uint256 => Rarity) public tokenRarity; // Could be done like this
    struct MintPass {
        bool claimed;
        bool receives;
    }

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
    event Refund(address indexed bidder, uint256 indexed amount, uint256 indexed bidId, uint256 timestamp);
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
        ERC721(name, symbol) 
        MintPassRarityGenerator(subscriptionId, vrfCoordinator, link, _keyHash) {
        // uint64 subscriptionId, address vrfCoordinator, address link, bytes32 _keyHash
        _baseTokenURI = baseTokenURI;
        totalBidsLimit = _totalBidsLimit;
        //start = block.timestamp;
        auctionDuration = _auctionDuration;
        lastBidAmount = _minimumBidAmount;
    }

    function getAllBids() public view returns (Bid[] memory) {
        return bidsArray;
    }

    function getUserBidIds(address _address) public view returns (uint256[] memory) {
        return userBidIds[_address];
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
        active = false;
        auctionDuration = block.timestamp - start;
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

    function claimPass() external onlyWhenFinished {
        // This assumes that the auction overpassed the total bids limit
        require(userBidIds[_msgSender()].length > 0 && (latestBidId <= totalBidsLimit || userBidIds[_msgSender()][userBidIds[_msgSender()].length-1] > latestBidId - totalBidsLimit), "User didn't win auction");

        // A user could have thousands of bids, may provoke a gas problem here
        for(uint i = 0; i < userBidIds[_msgSender()].length; i++) {
  
            if(bids[userBidIds[_msgSender()][i]].bidValue > 0 && (latestBidId <= totalBidsLimit || userBidIds[_msgSender()][i] > latestBidId - totalBidsLimit)) {

                bids[userBidIds[_msgSender()][i]].bidValue = 0;
        
                // id = 20000   20000  - (latestBidId - totalBidsLimit) = 20000 - (20000 - 9500) = 9500
                // id = 10000   10000  - (latestBidId - totalBidsLimit) = 15000 - (20000 - 9500) = 4500
                uint256 position = latestBidId <= totalBidsLimit ? userBidIds[_msgSender()][i] : userBidIds[_msgSender()][i] - (latestBidId - totalBidsLimit);
                Rarity rarity = _calculateRarityForBids(position);
                _safeMint(_msgSender(), _tokenIdTracker.current());
                mintingPassRarity[_tokenIdTracker.current()] = rarity;

                _tokenIdTracker.increment();

                emit PassClaimed(_msgSender(), _tokenIdTracker.current() - 1, userBidIds[_msgSender()][i], block.timestamp);
            }
        }
    }

    function bid(uint bidsAmount, uint bidValue) external payable onlyActive nonReentrant {
        require(bidValue > lastBidAmount, "There is not enough funds to make a bid");
        require(msg.value >= bidValue * bidsAmount, "There is not enough funds to make bids");
        require(bidsAmount <= 20, "Too many bids during 1 transaction");
        
        for(uint i = 0; i < bidsAmount; i++) {
            if(latestBidId > totalBidsLimit) {
                Bid storage bid = bids[latestBidId - totalBidsLimit]; 
                
                uint value = bid.bidValue;
                bid.bidValue = 0;

                // Danger: Similar to King of ether, could provoke denial of service, better to replace with call
                // Warning: Let users claim their own eth, this function is more expensive to use for people after the totalBidsLimit
                payable(bid.bidder).transfer(value);

                emit Refund(_msgSender(), bidValue, latestBidId - totalBidsLimit,  block.timestamp);
            }

            bids[latestBidId] = Bid(latestBidId, bidValue, _msgSender(), block.timestamp);
            userBidIndexes[_msgSender()][latestBidId] = userBidIds[_msgSender()].length - 1;
            userBidIds[_msgSender()].push(latestBidId);

            bidIndexes[_msgSender()][latestBidId] = bidsArray.length - 1;
            bidsArray.push(bids[latestBidId]);
            latestBidId++;

            emit BidPlaced(_msgSender(), bidValue, latestBidId - 1,  block.timestamp);
        }

        lastBidAmount = bidValue;
    }

    function updateBid(uint bidId, uint newBidValue) external payable onlyActive nonReentrant {
        require(newBidValue <= bids[bidId].bidValue + msg.value, "New bid amount must be bigger then original");
        require(msg.value > 0, "There is not enough funds to update bid");

        emit BidUpdated(_msgSender(), bids[bidId].bidValue, newBidValue, bidId,  block.timestamp);
        bids[bidId] = Bid(bidId, newBidValue, _msgSender(), block.timestamp);

        if(newBidValue > lastBidAmount) {
            lastBidAmount = newBidValue;
        }
    }

    function cancelBid(uint bidId) external onlyActive nonReentrant {
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


    function getRarity(uint256 userBidId) public returns (Rarity){
        uint256 position;
        
        if(latestBidId <= totalBidsLimit){ 
            position = userBidId;
        } else {
            uint256 result = latestBidId - totalBidsLimit; // 15 - 10 = 5
            require(userBidId > result, "User didn't win auction");
            // 6 - 5 = 1
            // 15 - 5 = 10
            position = userBidId - result; 
        }

        return _calculateRarityForBids(position);
    }

    // function _calculateRarityForBids(uint256 position) private returns (Rarity){
    //     if(position >= commonBottom && position <= commonTop) return Rarity.COMMON;
    //     if(position >= rareBottom && position <= rareTop) return Rarity.RARE;
    //     if(position >= epicBottom && position <= epicTop) return Rarity.EPIC;
    //     if(position >= epicRareBottom && position <= epicRareTop) return Rarity.EPIC_RARE;
    //     if(position >= misticBottom && position <= misticTop) return Rarity.MISTIC;
    //     if(position == extraCelestial) return Rarity.EXTRA_CELESTIAL;
    // }

    function addPromotionMintingAddress(address _beneficiary) public onlyOwner {
        promotionMintingAddresses.push(_beneficiary);
        promotionPasses[_beneficiary].receives = true;
    }

    function _calculateRarityForBids(uint256 position) private returns (Rarity){
        if(position >= 1 && position <= 5000) return Rarity.COMMON;
        if(position >= 5001 && position <= 7000) return Rarity.RARE;
        if(position >= 7001 && position <= 7999) return Rarity.EPIC;
        if(position >= 8000 && position <= 8800) return Rarity.EPIC_RARE;
        if(position >= 8801 && position <= 9300) return Rarity.LEGENDARY;
        if(position >= 9301 && position <= 9499) return Rarity.MYSTIC;
        if(position == 9500) return Rarity.EXTRA_CELESTIAL;
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
