//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./libraries/RandomGenerator.sol";

// We import this library to be able to use console.log
import "hardhat/console.sol";

// This is the main building block for smart contracts.
contract MintPasses is Context, ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;
    using SafeMath for uint256;

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;
    uint256 public totalBidsLimit;
    uint256 private _latestBidId = 1;
    uint256 public start;
    uint256 public minimumBidAmount;
    uint256 public auctionDuration;
    address public scionContract;
    address public treasury;

    enum Class {
        NONE,
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM,
        RUBY,
        ONYX
    }

    struct ClassLimits {
        uint256 bottomBidValue;
        uint256 topBidValue;
        uint256 timestamp;
        uint256 bottomAssetWeight;
        uint256 topAssetWeight;
    }

    struct BidInfo {
        uint256 bidIndex;
        address bidder;
        uint256 bidValue;
        uint256 timestamp;
        Class class;
        bool claimed;
    }

    struct MintPassInfo {
        Class class;
        uint256 random;
    }

    enum ListOption {
        ALL,
        OWNED
    }

    // class related
    mapping(Class => ClassLimits) public classLimits;

    // bid related
    mapping(uint256 => BidInfo) public bidInfos; // bidIndex -> BidInfo
    EnumerableSet.UintSet internal _allBids; // bidIndexes
    mapping(address => EnumerableSet.UintSet) internal _ownedBids; // user -> bidIndexes

    // promotion related
    EnumerableSet.AddressSet internal _promotionBeneficiaries;
    mapping(Class => uint256) public promotionPrices; // class -> price

    // mintPass related
    mapping(uint256 => MintPassInfo) public mintPassInfos; // mintPassId -> MintPassInfo

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
    event PromotionPassClaimed(
        address indexed beneficiary,
        uint256 indexed passId,
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

    /**
     * See {ERC721-tokenURI}.
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint256 _totalBidsLimit,
        uint256 _minimumBidAmount,
        uint256 _auctionDuration
    )
        // TODO assert non empty treasury
        // TODO assert non empty scionContract
        ERC721(name, symbol)
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

    function setTreasury(address _treasury) public onlyOwner {
        treasury = _treasury;
    }

    function setTotalLimit(uint256 _totalBidsLimit) external onlyOwner {
        totalBidsLimit = _totalBidsLimit;
    }

    function setScionAddress(address _scionContract) external onlyOwner {
        scionContract = _scionContract;
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
        override(ERC721Enumerable)
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

                emit PassClaimed(_msgSender(), tokenId, bidIndex, block.timestamp);
            }
        }
    }

    function mintPromotionPassBatch(Class[] memory classes) public onlyOwner {
        require(classes.length < 30, "Too many mintPass to mint");
        for (uint256 i = 0; i < classes.length; i++) {
            _mintMintPass(address(this), classes[i]);
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
        require(scionContract == _msgSender(), "Only scion contract can burn");
        _burn(tokenId);
    }

    function addPromotionMintingAddress(address _beneficiary) public onlyOwner nonReentrant {
        require(!_promotionBeneficiaries.contains(_beneficiary), "MintPasses: Already added");
        _promotionBeneficiaries.add(_beneficiary);
    }

    function setPricePerClassPromotion(Class[] memory classes, uint256[] memory prices)
        public
        onlyOwner
    {
        require(classes.length == prices.length, "Data mismatch");
        for (uint256 i = 0; i < classes.length; i++) {
            promotionPrices[classes[i]] = prices[i];
        }
    }

    function buyPromotionMintPass(uint256 _tokenId) external payable {
        require(promotionPrices[mintPassInfos[_tokenId].class] > 0, "Prices not set yet");
        require(_promotionBeneficiaries.contains(_msgSender()), "Not beneficiary");

        require(
            msg.value == promotionPrices[mintPassInfos[_tokenId].class],
            "There is not enough funds to buy"
        );
        _promotionBeneficiaries.remove(_msgSender());

        payable(treasury).transfer(msg.value);

        _transfer(address(this), _msgSender(), _tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
