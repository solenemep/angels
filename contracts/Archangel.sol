//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./abstracts/Angel.sol";
import "./Soul.sol";

contract Archangel is Angel, ERC721Enumerable {
    // Mint, receives the minting pass NFT, burns it to create a Scion
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for Soul;

    uint256 public constant BATCH = 7;

    Counters.Counter private _tokenIdTracker;

    uint256 public priceInSouls = 444e18;
    Soul public soul;

    string private _uri;

    mapping(uint256 => bool) public openToSale; // tokenId -> OK to be minted

    event ArchangelMinted(address indexed user, uint256 indexed tokenId, uint256 timestamp);

    constructor(address _soul, string memory _baseURIString) ERC721("Archangel", "ARCH") {
        soul = Soul(_soul);
        _uri = _baseURIString;
    }

    function setPriceInSouls(uint256 _priceInSouls) external override {
        priceInSouls = _priceInSouls;
    }

    function angelsLeft() external view override returns (uint256) {
        if (openToSale[_tokenIdTracker.current()]) {
            return BATCH - (_tokenIdTracker.current() % BATCH);
        } else {
            return 0;
        }
    }

    function getBatchIndex() external view override returns (uint256) {
        if (openToSale[_tokenIdTracker.current()]) {
            return (_tokenIdTracker.current() / BATCH) + 1;
        } else {
            return (_tokenIdTracker.current() / BATCH);
        }
    }

    function triggerBatchSale() external override {
        uint256 startTokenId = _tokenIdTracker.current();
        uint256 endTokenId = startTokenId + BATCH;

        for (uint256 i = startTokenId; i < endTokenId; i++) {
            openToSale[i] = true;
        }
    }

    function _mintArchangel(address _buyer, uint256 _tokenId) internal {
        _mint(_buyer, _tokenId);
    }

    function claimAngel() external override {
        uint256 newTokenId = _tokenIdTracker.current();
        require(openToSale[newTokenId] == true, "No archangel on sale");

        _tokenIdTracker.increment();

        openToSale[newTokenId] = false;

        soul.safeTransferFrom(msg.sender, address(this), priceInSouls);
        soul.burn(priceInSouls);

        _mintArchangel(msg.sender, newTokenId);

        emit ArchangelMinted(msg.sender, newTokenId, block.timestamp);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _uri;
    }
}
