//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Soul.sol";

contract Creature is Ownable, ReentrancyGuard, ERC721 {
    // Mint, receives the minting pass NFT, burns it to create a Scion
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for Soul;

    uint256 public constant BATCH = 7;

    Counters.Counter private _tokenIdTracker;

    uint256 public priceInSouls;
    Soul public soul;
    string private _uri;

    uint256 public currentBacthIndex;

    event CreatureMinted(address indexed user, uint256 indexed tokenId, uint256 timestamp);

    constructor(
        string memory _name,
        string memory _symbol,
        address _soul,
        string memory _uriBase
    ) ERC721(_name, _symbol) {
        soul = Soul(_soul);
        _uri = _uriBase;
    }

    function isOnSale(uint256 _tokenId) public view returns (bool) {
        if (_tokenId < _tokenIdTracker.current()) {
            return false;
        } else {
            return _tokenId < currentBacthIndex * BATCH ? true : false;
        }
    }

    function currentBatchMinted() external view returns (uint256) {
        if (
            currentBacthIndex > 0 &&
            (currentBacthIndex - 1) * BATCH < _tokenIdTracker.current() &&
            _tokenIdTracker.current() <= currentBacthIndex * BATCH
        ) {
            return _tokenIdTracker.current() - ((currentBacthIndex - 1) * BATCH);
        } else {
            return 0;
        }
    }

    function currentBacthLeft() public view returns (uint256) {
        if (
            currentBacthIndex > 0 &&
            (currentBacthIndex - 1) * BATCH <= _tokenIdTracker.current() &&
            _tokenIdTracker.current() < currentBacthIndex * BATCH
        ) {
            return (currentBacthIndex * BATCH) - _tokenIdTracker.current();
        } else {
            return 0;
        }
    }

    function triggerBatchSale(uint256 _priceInSouls) external onlyOwner {
        require(_priceInSouls > 0, "Price should be higher than 0");
        priceInSouls = _priceInSouls;

        currentBacthIndex++;
    }

    function claimCreature() external nonReentrant {
        uint256 newTokenId = _tokenIdTracker.current();
        require(isOnSale(newTokenId) == true, "No creature on sale");

        _tokenIdTracker.increment();

        soul.safeTransferFrom(msg.sender, address(this), priceInSouls);
        soul.burn(priceInSouls);

        _mint(msg.sender, newTokenId);

        emit CreatureMinted(msg.sender, newTokenId, block.timestamp);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _uri;
    }
}
