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
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./MintPassRarityGenerator.sol";

// We import this library to be able to use console.log
import "hardhat/console.sol";

// This is the main building block for smart contracts.
contract MintPasses is
    Context,
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard,
    MintPassRarityGenerator
{
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using Math for uint256;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;
    uint256 public totalBidsLimit;
    uint256 private _latestBidId = 1;
    uint256 public start;
    uint256 public minimumBidAmount;
    uint256 public auctionDuration;
    bool public active;
    address public scionContract;
    address public treasury;

    enum BidClass {
        NONE,
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM,
        RUBY,
        ONYX
    }

    mapping(uint256 => BidInfo) public bidInfos; // bidIndex -> BidInfo
    EnumerableSet.UintSet internal _allBids; // bidIndexes
    mapping(address => EnumerableSet.UintSet) internal _ownedBids; // user -> bidIndex

    mapping(uint256 => BidClass) public mintingPassClass; // mintpass -> class
    mapping(uint256 => uint256) public mintingPassRandom; // mintpass -> random

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

    mapping(BidClass => Class) public classes;
    mapping(address => MintPass) public promotionPasses;
    address[] public promotionMintingAddresses;

    //BidInfo[] bidsArray;

    struct BidInfo {
        address bidder;
        uint256 bidValue;
        uint256 timestamp;
        BidClass class;
        bool claimed;
    }

    enum ListOption {
        ALL,
        OWNED
    }

    event BidPlaced(
        address indexed bidder,
        uint256 indexed amount,
        uint256 indexed bidId,
        uint256 timestamp
    );
    event BidCanceled(
        address indexed bidder,
        uint256 indexed amount,
        uint256 indexed bidId,
        uint256 timestamp
    );
    event BidUpdated(
        address indexed bidder,
        uint256 previousAmount,
        uint256 indexed amount,
        uint256 indexed bidId,
        uint256 timestamp
    );
    event PassClaimed(
        address indexed bidder,
        uint256 indexed passId,
        uint256 indexed bidId,
        uint256 timestamp
    );

    modifier onlyActive() {
        require(
            active &&
                (block.timestamp > start &&
                    block.timestamp < start + auctionDuration),
            "Inactive"
        );
        _;
    }

    modifier onlyWhenFinished() {
        require(
            active && (block.timestamp >= start + auctionDuration),
            "Auction inactive or hasn't finish yet"
        );
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
        uint256 _auctionDuration,
        uint64 subscriptionId,
        address vrfCoordinator,
        address link,
        bytes32 _keyHash
    )
        // TODO assert non empty treasury
        ERC721(name, symbol)
        MintPassRarityGenerator(subscriptionId, vrfCoordinator, link, _keyHash)
    {
        // uint64 subscriptionId, address vrfCoordinator, address link, bytes32 _keyHash
        _baseTokenURI = baseTokenURI;
        totalBidsLimit = _totalBidsLimit;
        //start = block.timestamp;
        auctionDuration = _auctionDuration;
        minimumBidAmount = _minimumBidAmount;
    }

    function isAuctionFinished() public view returns (bool) {
        return block.timestamp >= start + auctionDuration;
    }

    function countAllBids() external view returns (uint256) {
        return _allBids.length();
    }

    function countOwnedBids() external view returns (uint256) {
        return _ownedBids[_msgSender()].length();
    }

    function getListBids(
        uint256 offset,
        uint256 limit,
        ListOption listOption
    ) public view returns (BidInfo[] memory bidPublicInfos) {
        uint256 count;
        if (listOption == ListOption.ALL) {
            count = _allBids.length();
        } else if (listOption == ListOption.OWNED) {
            count = _ownedBids[msg.sender].length();
        }

        uint256 to = (offset.add(limit)).min(count).max(offset);
        bidPublicInfos = new BidInfo[](to.sub(offset));

        for (uint256 i = offset; i < to; i++) {
            uint256 bidIndex;
            if (listOption == ListOption.ALL) {
                bidIndex = _allBids.at(i);
            } else if (listOption == ListOption.OWNED) {
                bidIndex = _ownedBids[msg.sender].at(i);
            }

            uint256 newIndex = i.sub(offset);
            bidPublicInfos[newIndex] = getBidInfo(bidIndex);
        }
    }

    function getBidInfo(uint256 bidIndex)
        public
        view
        returns (BidInfo memory bidPublicInfo)
    {
        bidPublicInfo = bidInfos[bidIndex];
        bidPublicInfo.class = _getBidClass(bidIndex);
    }

    function _getBidClass(uint256 _bidIndex)
        internal
        view
        returns (BidClass bidClass)
    {
        uint256 bidValue = bidInfos[_bidIndex].bidValue;

        if (bidValue < classes[BidClass.BRONZE].bottom) {
            bidClass = BidClass.NONE;
        } else if (bidValue < classes[BidClass.BRONZE].top) {
            bidClass = BidClass.BRONZE;
        } else if (
            bidValue >= classes[BidClass.SILVER].bottom &&
            bidValue < classes[BidClass.SILVER].top
        ) {
            bidClass = BidClass.SILVER;
        } else if (
            bidValue >= classes[BidClass.GOLD].bottom &&
            bidValue < classes[BidClass.GOLD].top
        ) {
            bidClass = BidClass.GOLD;
        } else if (
            bidValue >= classes[BidClass.PLATINUM].bottom &&
            bidValue < classes[BidClass.PLATINUM].top
        ) {
            bidClass = BidClass.PLATINUM;
        } else if (
            bidValue >= classes[BidClass.RUBY].bottom &&
            bidValue < classes[BidClass.RUBY].top
        ) {
            bidClass = BidClass.RUBY;
        } else if (
            bidValue >= classes[BidClass.ONYX].bottom &&
            bidValue < classes[BidClass.ONYX].top
        ) {
            bidClass = BidClass.ONYX;
        }
    }

    function getBidsClasses() public view returns (BidClass[] memory) {
        BidClass[] memory result = new BidClass[](
            _ownedBids[_msgSender()].length()
        );

        for (uint256 i = 0; i < _ownedBids[_msgSender()].length(); i++) {
            result[i] = _getBidClass(_ownedBids[_msgSender()].at(i));
        }

        return result;
    }

    function setClasses(
        BidClass[] memory _bidClasses,
        uint256[] memory _bottom,
        uint256[] memory _top,
        uint256[] memory _timestamp
    ) public {
        require(
            _bidClasses.length == _bottom.length &&
                _bottom.length == _top.length &&
                _top.length == _timestamp.length
        );
        for (uint256 i = 0; i < _bidClasses.length; i++) {
            setClass(_bidClasses[i], _bottom[i], _top[i], _timestamp[i]);
        }
    }

    function setClass(
        BidClass _bidClass,
        uint256 _bottom,
        uint256 _top,
        uint256 _timestamp
    ) public onlyOwner {
        classes[_bidClass] = Class(_bottom, _top, _timestamp);
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

    function setStart(uint256 _auctionDuration, uint256 _auctionStart)
        external
        onlyOwner
    {
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

    function userAvailableToClaim(address _address)
        public
        view
        returns (uint256)
    {
        uint256 result;

        for (uint256 i = 0; i < _ownedBids[_address].length(); i++) {
            if (_getBidClass(_ownedBids[_address].at(i)) != BidClass.NONE) {
                result++;
            }
        }

        return result;
    }

    function random(uint256 _tokenId) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender,
                        _tokenId
                    )
                )
            ) % 1000;
    }

    function claimPass(uint256[] memory bidIndexes) external onlyWhenFinished {
        for (uint256 i = 0; i < bidIndexes.length; i++) {
            uint256 bidIndex = bidIndexes[i];

            /// @dev no use of require to avoid revert for all transaction
            /// @dev not checking bidValue > 0 as cannot bid with bidValue < minimumBidAmount
            if (
                bidInfos[bidIndex].bidder == _msgSender() &&
                !bidInfos[bidIndex].claimed &&
                _getBidClass(bidIndex) != BidClass.NONE
            ) {
                mintingPassClass[_tokenIdTracker.current()] = _getBidClass(
                    bidIndex
                );
                mintingPassRandom[_tokenIdTracker.current()] = random(
                    _tokenIdTracker.current()
                );
                payable(treasury).transfer(bidInfos[bidIndex].bidValue);

                _safeMint(_msgSender(), _tokenIdTracker.current());

                _tokenIdTracker.increment();

                bidInfos[bidIndex].claimed = true;

                emit PassClaimed(
                    _msgSender(),
                    _tokenIdTracker.current() - 1,
                    bidIndex,
                    block.timestamp
                );
            }
        }
    }

    function bid(uint256 bidsAmount, uint256 bidValue)
        external
        payable
        onlyActive
        nonReentrant
    {
        require(
            bidValue > minimumBidAmount,
            "Bid value must be bigger then minimum bid"
        );
        require(
            msg.value >= bidValue * bidsAmount,
            "There is not enough funds to make bids"
        );
        require(bidsAmount <= 30, "Too many bids during 1 transaction");

        for (uint256 i = 0; i < bidsAmount; i++) {
            uint256 newBidIndex = _latestBidId;
            bidInfos[newBidIndex].bidder = _msgSender();
            bidInfos[newBidIndex].bidValue = bidValue;
            bidInfos[newBidIndex].timestamp = block.timestamp;

            _allBids.add(newBidIndex);
            _ownedBids[_msgSender()].add(newBidIndex);

            _latestBidId++;

            emit BidPlaced(
                _msgSender(),
                bidValue,
                newBidIndex,
                block.timestamp
            );
        }
    }

    function updateBid(uint256 bidIndex)
        external
        payable
        onlyActive
        nonReentrant
    {
        require(msg.value > 0, "There is not enough funds to update bid");
        require(
            _msgSender() == bidInfos[bidIndex].bidder,
            "Not the owner of the bid"
        );
        uint256 lastBidValue = bidInfos[bidIndex].bidValue;

        bidInfos[bidIndex].bidValue = bidInfos[bidIndex].bidValue.add(
            msg.value
        );
        bidInfos[bidIndex].timestamp = block.timestamp;

        emit BidUpdated(
            _msgSender(),
            lastBidValue,
            bidInfos[bidIndex].bidValue,
            bidIndex,
            block.timestamp
        );
    }

    function cancelBid(uint256 bidIndex) external nonReentrant {
        //TODO we should't allow canceling bid after the auction is over, even if no limits set
        require(
            (block.timestamp > start &&
                block.timestamp < start + auctionDuration) ||
                (block.timestamp > start + auctionDuration &&
                    classes[BidClass.BRONZE].top != 0 &&
                    _getBidClass(bidIndex) == BidClass.NONE)
        );
        require(
            _msgSender() == bidInfos[bidIndex].bidder,
            "Not the owner of the bid"
        );
        uint256 bidValue = bidInfos[bidIndex].bidValue;

        _allBids.remove(bidIndex);
        _ownedBids[_msgSender()].remove(bidIndex);

        payable(_msgSender()).transfer(bidValue);
        emit BidCanceled(_msgSender(), bidValue, bidIndex, block.timestamp);
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
        require(userPromotionPass.receives, "MintPasses: invalid user");
        require(!userPromotionPass.claimed, "MintPasses: user already claimed");

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
