//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// We import this library to be able to use console.log
import "hardhat/console.sol";

// This is the main building block for smart contracts.
contract MintPasses is Context, ERC721Enumerable, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    string private _baseTokenURI;
    uint256 public totalBidsLimit;
    uint256 public totalBids;
    uint256 public latestBidId = 1;
    uint256 public start;
    uint256 public auctionDuration;
    uint256 public lastBidAmount;
    bool public active;

    mapping (uint256 => Bid) public bids;
    mapping (address => uint256[]) public userBidIds;

    Bid[] bidsArray;

    struct Bid {
        uint256 id;
        uint256 bidValue;
        address bidder;
        uint256 timestamp;
    }

    event BidPlaced(address indexed bidder, uint256 indexed amount, uint256 indexed bidId, uint256 timestamp);
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
        uint256 _start,
        uint256 _auctionDuration
    ) ERC721(name, symbol) {
        _baseTokenURI = baseTokenURI;
        totalBidsLimit = _totalBidsLimit;
        start = block.timestamp;
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
        require(userBidIds[msg.sender][userBidIds[msg.sender].length-1] >= latestBidId - totalBidsLimit, "User didn't win auction");

        for(uint i = 0; i < userBidIds[msg.sender].length; i++) {
            if(bids[userBidIds[msg.sender][i]].bidValue > 0 && userBidIds[msg.sender][i] >= latestBidId - totalBidsLimit) {

                bids[userBidIds[msg.sender][i]].bidValue = 0;

                _safeMint(msg.sender, _tokenIdTracker.current());
                _tokenIdTracker.increment();

                emit PassClaimed(msg.sender, _tokenIdTracker.current() - 1, userBidIds[msg.sender][i], block.timestamp);
            }
        }
    }

    function bid(uint bidsAmount, uint bidValue) external payable onlyActive nonReentrant {
        require(bidValue > lastBidAmount, "There is not enough funds to make a bid");
        require(msg.value >= bidValue * bidsAmount, "There is not enough funds to make bids");
        require(bidsAmount <= 20, "Too much bids during 1 transaction");
        
        for(uint i = 0; i < bidsAmount; i++) {
            if(latestBidId > totalBidsLimit) {
                Bid storage bid = bids[latestBidId - totalBidsLimit];
                
                uint value = bid.bidValue;
                bid.bidValue = 0;

                payable(bid.bidder).transfer(value);

                emit Refund(msg.sender, bidValue, latestBidId - totalBidsLimit,  block.timestamp);
            }

            bids[latestBidId] = Bid(latestBidId, bidValue, msg.sender, block.timestamp);
            userBidIds[msg.sender].push(latestBidId);

            bidsArray.push(bids[latestBidId]);
            latestBidId++;

            emit BidPlaced(msg.sender, msg.value, latestBidId - 1,  block.timestamp);
        }

        lastBidAmount = bidValue;
    }

    function adminWithdraw(IERC20 token) external onlyOwner {
        if (token == IERC20(address(0))) {
            // allow to rescue ether
            payable(owner()).transfer(address(this).balance);
        } else {
            uint256 withdrawAmount = token.balanceOf(address(this));
            if (withdrawAmount > 0) {
                token.safeTransfer(address(msg.sender), withdrawAmount);
            }
        }
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
}
