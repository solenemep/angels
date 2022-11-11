//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Soul.sol";

contract Watcher is Ownable, ERC721Enumerable, ReentrancyGuard {
    // Mint, receives the minting pass NFT, burns it to create a Scion
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for Soul;

    uint256 public constant BATCH = 7;

    Counters.Counter private _tokenIdTracker;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    uint256 public priceInSouls = 444e18;
    uint256 public latestClaimed;
    Soul public soul;

    mapping(uint256 => bool) public openToSale; // tokenId -> OK to be minted

    event WatcherMinted(address indexed user, uint256 indexed tokenId, uint256 timestamp);

    constructor(address _soul) ERC721("Watcher", "ARCH") {
        soul = Soul(_soul);
    }

    function setPriceInSouls(uint256 _priceInSouls) external onlyOwner {
        priceInSouls = _priceInSouls;
    }

    function watcherssLeft() public view returns (uint256) {
        return BATCH - (latestClaimed + 1);
    }

    function triggerBatchSale() external onlyOwner {
        uint256 startTokenId = _tokenIdTracker.current();
        uint256 endTokenId = startTokenId + BATCH;

        for (uint256 i = startTokenId; i < endTokenId; i++) {
            openToSale[i] = true;
        }
    }

    function _mintWatcher(
        address _buyer,
        uint256 _tokenId,
        string memory _tokenURI
    ) internal {
        _mint(_buyer, _tokenId);
        _setTokenURI(_tokenId, _tokenURI);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    function claimWatcher() external nonReentrant {
        uint256 newTokenId = _tokenIdTracker.current();
        require(openToSale[newTokenId] == true, "No watcher on sale");

        _tokenIdTracker.increment();
        latestClaimed = newTokenId;
        openToSale[newTokenId] = false;

        soul.safeTransferFrom(msg.sender, address(this), priceInSouls);
        soul.burn(priceInSouls);

        _mintWatcher(msg.sender, newTokenId, "");

        emit WatcherMinted(msg.sender, newTokenId, block.timestamp);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    // Sets the uri, url of ipfs
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
        _setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "";
    }
}
