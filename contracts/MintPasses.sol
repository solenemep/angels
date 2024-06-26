//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Registry.sol";

import "./libraries/RandomGenerator.sol";

import "./interfaces/IMintPasses.sol";

contract MintPasses is
    IMintPasses,
    OwnableUpgradeable,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable
{
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using Math for uint256;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdTracker;

    address public treasury;
    address public mintPassesHolderAddress;
    address public scionAddress;

    string private _baseTokenURI;
    uint256 private _latestBidId;
    uint256 public start;
    uint256 public minimumBidAmount;
    uint256 public auctionDuration;

    // class related
    mapping(Class => ClassLimits) public override classLimits;

    // bid related
    mapping(uint256 => BidInfo) public bidInfos; // bidIndex -> BidInfo
    EnumerableSet.UintSet internal _allBids; // bidIndexes
    mapping(address => EnumerableSet.UintSet) internal _ownedBids; // user -> bidIndexes

    // mintPass related
    mapping(uint256 => MintPassInfo) public override mintPassInfos; // mintPassId -> MintPassInfo

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
        Class class,
        uint256 timestamp
    );

    modifier onlyActive() {
        require(
            (block.timestamp > start && block.timestamp < start + auctionDuration),
            "Auction inactive"
        );
        _;
    }

    modifier onlyInactive() {
        require(block.timestamp >= start + auctionDuration, "Auction active");
        _;
    }

    modifier onlyIfClassSet() {
        require(classLimits[Class.BRONZE].topBidValue != 0, "Classes not set");
        _;
    }

    function __MintPasses_init(
        string memory _name,
        string memory _symbol,
        string memory baseTokenURI,
        uint256 _minimumBidAmount,
        uint256 _auctionDuration
    ) external initializer {
        _latestBidId = 1;
        _baseTokenURI = baseTokenURI;
        auctionDuration = _auctionDuration;
        minimumBidAmount = _minimumBidAmount;

        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC721_init(_name, _symbol);
    }

    function setDependencies(address registryAddress) external onlyOwner {
        treasury = Registry(registryAddress).getContract("TREASURY");
        mintPassesHolderAddress = Registry(registryAddress).getContract("MINTPASS_HOLDER");
        scionAddress = Registry(registryAddress).getContract("SCION");
    }

    function isAuctionFinished() public view returns (bool) {
        return block.timestamp >= start + auctionDuration;
    }

    function countAllBids() external view returns (uint256) {
        return _allBids.length();
    }

    function countOwnedBids(address _user) external view returns (uint256) {
        return _ownedBids[_user].length();
    }

    function getListBids(
        uint256 offset,
        uint256 limit,
        ListOption listOption,
        address bidder
    ) public view returns (BidInfo[] memory bidPublicInfos) {
        uint256 count;
        if (listOption == ListOption.ALL) {
            count = _allBids.length();
        } else if (listOption == ListOption.OWNED) {
            count = _ownedBids[bidder].length();
        }

        uint256 to = (offset.add(limit)).min(count).max(offset);

        bidPublicInfos = new BidInfo[](to.sub(offset));

        for (uint256 i = offset; i < to; i++) {
            uint256 bidIndex;
            if (listOption == ListOption.ALL) {
                bidIndex = _allBids.at(i);
            } else if (listOption == ListOption.OWNED) {
                bidIndex = _ownedBids[bidder].at(i);
            }

            uint256 newIndex = i.sub(offset);
            bidPublicInfos[newIndex] = getBidInfo(bidIndex);
        }
    }

    function getBidInfo(uint256 bidIndex) public view returns (BidInfo memory bidPublicInfo) {
        bidPublicInfo = bidInfos[bidIndex];
        bidPublicInfo.class = _getBidClass(bidIndex);
    }

    function _getBidClass(uint256 _bidIndex) internal view returns (Class bidClass) {
        uint256 bidValue = bidInfos[_bidIndex].bidValue;

        if (bidValue < classLimits[Class.BRONZE].bottomBidValue) {
            bidClass = Class.NONE;
        } else if (bidValue < classLimits[Class.BRONZE].topBidValue) {
            bidClass = Class.BRONZE;
        } else if (bidValue < classLimits[Class.SILVER].topBidValue) {
            bidClass = Class.SILVER;
        } else if (bidValue < classLimits[Class.GOLD].topBidValue) {
            bidClass = Class.GOLD;
        } else if (bidValue < classLimits[Class.PLATINUM].topBidValue) {
            bidClass = Class.PLATINUM;
        } else if (bidValue < classLimits[Class.RUBY].topBidValue) {
            bidClass = Class.RUBY;
        } else if (bidValue < classLimits[Class.ONYX].topBidValue) {
            bidClass = Class.ONYX;
        }
    }

    function getBidsClasses() public view returns (Class[] memory) {
        Class[] memory result = new Class[](_ownedBids[_msgSender()].length());

        for (uint256 i = 0; i < _ownedBids[_msgSender()].length(); i++) {
            result[i] = _getBidClass(_ownedBids[_msgSender()].at(i));
        }

        return result;
    }

    function setClassesBidValueLimits(
        Class[] memory _classes,
        uint256[] memory _bottomBidValues,
        uint256[] memory _topBidValues,
        uint256[] memory _timestamps
    ) public {
        require(
            _classes.length == _bottomBidValues.length &&
                _bottomBidValues.length == _topBidValues.length &&
                _topBidValues.length == _timestamps.length
        );
        for (uint256 i = 0; i < _classes.length; i++) {
            setClassBidValueLimit(
                _classes[i],
                _bottomBidValues[i],
                _topBidValues[i],
                _timestamps[i]
            );
        }
    }

    function setClassBidValueLimit(
        Class _class,
        uint256 _bottomBidValue,
        uint256 _topBidValue,
        uint256 _timestamp
    ) public onlyOwner onlyInactive {
        classLimits[_class].bottomBidValue = _bottomBidValue;
        classLimits[_class].topBidValue = _topBidValue;
        classLimits[_class].timestamp = _timestamp;
    }

    function setClassesWeightLimits(
        Class[] memory _classes,
        uint256[] memory _bottomAssetWeights,
        uint256[] memory _topAssetWeights
    ) public {
        require(
            _classes.length == _bottomAssetWeights.length &&
                _bottomAssetWeights.length == _topAssetWeights.length
        );
        for (uint256 i = 0; i < _classes.length; i++) {
            setClassWeightLimit(_classes[i], _bottomAssetWeights[i], _topAssetWeights[i]);
        }
    }

    function setClassWeightLimit(
        Class _class,
        uint256 _bottomAssetWeight,
        uint256 _topAssetWeight
    ) public onlyOwner {
        classLimits[_class].bottomAssetWeight = _bottomAssetWeight;
        classLimits[_class].topAssetWeight = _topAssetWeight;
    }

    function startAuction(uint256 _auctionDuration, uint256 _auctionStart) external onlyOwner {
        start = _auctionStart;
        auctionDuration = _auctionDuration * 1 minutes;
    }

    function finishAuction() external onlyOwner {
        auctionDuration = block.timestamp > start ? block.timestamp - start : 0;
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

    function bid(uint256 bidsAmount, uint256 bidValue) external payable onlyActive nonReentrant {
        require(bidValue > minimumBidAmount, "Bid value must be bigger then minimum bid");
        require(msg.value == bidValue * bidsAmount, "There is not enough funds to make bids");
        require(bidsAmount <= 30, "Too many bids during 1 transaction");

        for (uint256 i = 0; i < bidsAmount; i++) {
            uint256 newBidIndex = _latestBidId;
            bidInfos[newBidIndex].bidIndex = newBidIndex;
            bidInfos[newBidIndex].bidder = _msgSender();
            bidInfos[newBidIndex].bidValue = bidValue;
            bidInfos[newBidIndex].timestamp = block.timestamp;

            _allBids.add(newBidIndex);
            _ownedBids[_msgSender()].add(newBidIndex);

            _latestBidId++;

            emit BidPlaced(_msgSender(), bidValue, newBidIndex, block.timestamp);
        }
    }

    function updateBid(uint256 bidIndex) external payable onlyActive nonReentrant {
        require(msg.value > 0, "There is not enough funds to update bid");
        require(_msgSender() == bidInfos[bidIndex].bidder, "Not the owner of the bid");
        uint256 lastBidValue = bidInfos[bidIndex].bidValue;

        bidInfos[bidIndex].bidValue = bidInfos[bidIndex].bidValue.add(msg.value);
        bidInfos[bidIndex].timestamp = block.timestamp;

        emit BidUpdated(
            _msgSender(),
            lastBidValue,
            bidInfos[bidIndex].bidValue,
            bidIndex,
            block.timestamp
        );
    }

    function cancelBid(uint256 bidIndex) external onlyInactive onlyIfClassSet nonReentrant {
        require(_msgSender() == bidInfos[bidIndex].bidder, "Not the owner of the bid");
        require(!bidInfos[bidIndex].claimed, "Already cancelced or claimed");
        uint256 bidValue = bidInfos[bidIndex].bidValue;

        _allBids.remove(bidIndex);
        _ownedBids[_msgSender()].remove(bidIndex);

        bidInfos[bidIndex].claimed = true;

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
        override(ERC721Upgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function claimPass(uint256[] memory bidIndexes)
        external
        onlyInactive
        onlyIfClassSet
        nonReentrant
    {
        require(bidIndexes.length <= 30, "Too much indexes");
        for (uint256 i = 0; i < bidIndexes.length; i++) {
            uint256 bidIndex = bidIndexes[i];
            Class class = _getBidClass(bidIndex);

            /// @dev no use of require to avoid revert for all transaction
            /// @dev not checking bidValue > 0 as cannot bid with bidValue < minimumBidAmount
            if (
                bidInfos[bidIndex].bidder == _msgSender() &&
                !bidInfos[bidIndex].claimed &&
                class != Class.NONE
            ) {
                payable(treasury).transfer(bidInfos[bidIndex].bidValue);
                bidInfos[bidIndex].claimed = true;

                uint256 tokenId = _mintMintPass(_msgSender(), class);

                emit PassClaimed(_msgSender(), tokenId, bidIndex, class, block.timestamp);
            }
        }
    }

    function mintPromotionPassBatch(Class[] memory classes) public onlyOwner {
        require(classes.length < 30, "Too many mintPass to mint");
        for (uint256 i = 0; i < classes.length; i++) {
            _mintMintPass(mintPassesHolderAddress, classes[i]);
        }
    }

    function _mintMintPass(address user, Class class) internal returns (uint256 newTokenId) {
        newTokenId = _tokenIdTracker.current();

        mintPassInfos[newTokenId].class = class;
        mintPassInfos[newTokenId].random = RandomGenerator.random(user, 1000, newTokenId);

        _safeMint(user, newTokenId);
        _tokenIdTracker.increment();
    }

    function burn(uint256 tokenId) external {
        require(scionAddress == _msgSender(), "Only scion contract can burn");
        _burn(tokenId);
    }
}
