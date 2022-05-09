//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./Soul.sol";


contract Archangel is Ownable, ERC721Enumerable {
    // Mint, receives the minting pass NFT, burns it to create a Scion  
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for Soul;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    
    Counters.Counter private _tokenIdTracker;

    /**
        @dev tokenId to nesting start time (0 = not nesting).
     */
    mapping(uint256 => uint256) private nestingStarted;

    /**
        @dev Cumulative per-token nesting, excluding the current period.
     */
    mapping(uint256 => uint256) private nestingTotal;

    uint256 priceInSouls = 444e18;
    uint256 latestClaimed;
    Soul public soul;

    event ArchangelMinted(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event ArchangelClaimed(address indexed user, uint256 indexed tokenId, uint256 timestamp);
    event Nested(uint256 indexed tokenId);
    event Unnested(uint256 indexed tokenId);

    constructor(address _soul) ERC721("Archangel", "ARCH") {
        soul = Soul(_soul);
    }

    modifier onlyApprovedOrOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == _msgSender() ||
                getApproved(tokenId) == _msgSender(),
            "ERC721ACommon: Not approved nor owner"
        );
        _;
    }

    function nestingPeriod(uint256 tokenId) external view returns (bool nesting, uint256 current, uint256 total) {
        uint256 start = nestingStarted[tokenId];
        if (start != 0) {
            nesting = true;
            current = block.timestamp - start;
        }
        total = current + nestingTotal[tokenId];
    }

    /**
        @notice Whether nesting is currently allowed.
        @dev If false then nesting is blocked, but unnesting is always allowed.
     */
    bool public nestingOpen = false;

    /**
        @notice Toggles the `nestingOpen` flag.
     */
    function setNestingOpen(bool open) external onlyOwner {
        nestingOpen = open;
    }

    function toggleNesting(uint256[] calldata tokenIds) external {
        uint256 n = tokenIds.length;
        for (uint256 i = 0; i < n; ++i) {
            toggleNesting(tokenIds[i]);
        }
    }

    /**
        @notice Changes the Angel's nesting status.
    */
    function toggleNesting(uint256 tokenId) internal onlyApprovedOrOwner(tokenId) {
        uint256 start = nestingStarted[tokenId];
        if (start == 0) {
            require(nestingOpen, "Angels: nesting closed");
            nestingStarted[tokenId] = block.timestamp;
            emit Nested(tokenId);
        } else {
            nestingTotal[tokenId] += block.timestamp - start;
            nestingStarted[tokenId] = 0;
            emit Unnested(tokenId);
        }
    }

    function setPriceInSouls(uint256 _priceInSouls) external onlyOwner {
        priceInSouls = _priceInSouls;
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

    function mint(string memory _tokenURI) public onlyOwner {
        require(_tokenIdTracker.current() <= 6, "Total Archangels amount reached");
        _mint(address(this), _tokenIdTracker.current());

        _setTokenURI(_tokenIdTracker.current(), _tokenURI);
        emit ArchangelMinted(msg.sender, _tokenIdTracker.current(), block.timestamp);

        _tokenIdTracker.increment();
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

    function claimArchangel() public {
        require(latestClaimed <= 6, "Total Archangels amount reached");
        soul.safeTransferFrom(msg.sender, address(this), priceInSouls);
        soul.burn(priceInSouls);

        emit ArchangelClaimed(msg.sender, latestClaimed, block.timestamp);
        _safeTransfer(address(this), msg.sender, latestClaimed++, "");
    }

    function archangelsLeft() public view returns(uint256) {
        return 6 - latestClaimed + 1;
    }
    
    // Sets the uri, url of ipfs
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
       _setTokenURI(tokenId, _tokenURI);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "";
    }
}