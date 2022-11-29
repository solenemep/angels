//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";

import "./Registry.sol";
import "./tokens/Soul.sol";

contract Creature is OwnableUpgradeable, ERC721Upgradeable, ReentrancyGuardUpgradeable {
    // Mint, receives the minting pass NFT, burns it to create a Scion
    using Counters for Counters.Counter;

    Soul public soul;

    uint256 public constant BATCH = 7;

    uint256 public currentBacthIndex;
    Counters.Counter private _tokenIdTracker;

    uint256 public priceInSouls;
    string private _uri;

    event CreatureMinted(address indexed user, uint256 indexed tokenId, uint256 timestamp);

    function __Creature_init(
        string memory _name,
        string memory _symbol,
        string memory _uriBase
    ) internal onlyInitializing {
        _uri = _uriBase;

        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC721_init(_name, _symbol);
    }

    function setDependencies(address registryAddress) external onlyOwner {
        soul = Soul(Registry(registryAddress).getContract("SOUL"));
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

        soul.transferFrom(_msgSender(), address(this), priceInSouls);
        soul.burn(priceInSouls);

        _mint(_msgSender(), newTokenId);

        emit CreatureMinted(_msgSender(), newTokenId, block.timestamp);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _uri;
    }
}
