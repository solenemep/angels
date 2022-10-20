//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MintPasses.sol";

import "./libraries/RandomGenerator.sol";
import "./interfaces/IAssetRegistry.sol";

contract Scion is Ownable, ERC721Enumerable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IAssetRegistry public assetsRegistry;
    MintPasses public mintPasses;
    Counters.Counter private _tokenIdTracker;

    uint256 public constant priceForRarityInSouls = 100e18;
    uint256 public constant BP = 10000;
    uint256 private constant MAX_WEIGHT = 2500;

    string private _baseTokenURI;

    IERC20 public soul;
    IERC20 public keter;

    struct Scions {
        // Mandatory
        IAssetRegistry.AssetInfo background;
        IAssetRegistry.AssetInfo halo;
        IAssetRegistry.AssetInfo head;
        IAssetRegistry.AssetInfo body;
        // Optional
        IAssetRegistry.AssetInfo wings;
        IAssetRegistry.AssetInfo hands;
        IAssetRegistry.AssetInfo sigil;
    }

    struct RerollChances {
        uint256 downgrade;
        uint256 sameWeight;
        uint256 rarityPlus;
    }

    // scion related
    mapping(uint256 => Scions) public scionsData; // tokenId -> Scions

    // reroll related
    RerollChances private _rerollChances;

    event Reroll(
        uint256 indexed _tokenId,
        uint256 indexed _assetId,
        uint256 _previousRarity,
        int256 _newRarity,
        string _newAsset,
        Scions _assets,
        uint256 _price,
        uint256 _timestamp,
        address indexed _user
    );
    event AssetGenerated(
        uint256 indexed _tokenId,
        uint256 indexed _assetId,
        int256 _rarity,
        uint256 _timestamp
    );
    event ScionClaimed(
        address indexed _user,
        uint256 indexed _tokenId,
        uint256 mintPassId,
        Scions _assets,
        uint256 _timestamp
    );
    event RandomGenerated(uint256 random);

    constructor(
        address _mintPasses,
        address _soul,
        address _keter,
        address _assetsRegistry,
        string memory name,
        string memory symbol,
        string memory baseTokenURI,
        uint256 _downgrade,
        uint256 _sameWeight,
        uint256 _rarityPlus
    ) ERC721(name, symbol) {
        mintPasses = MintPasses(_mintPasses);
        assetsRegistry = IAssetRegistry(_assetsRegistry);
        soul = IERC20(_soul);
        keter = IERC20(_keter);
        _baseTokenURI = baseTokenURI;

        _rerollChances = RerollChances(_downgrade, _sameWeight, _rarityPlus);
    }

    modifier onlyApprovedOrOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == _msgSender() || getApproved(tokenId) == _msgSender(),
            "ERC721ACommon: Not approved nor owner"
        );
        _;
    }

    function baseURI() public view returns (string memory) {
        return _baseURI();
    }

    function setBaseURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function rerollChances(uint256 _assetId, uint256 weight)
        public
        view
        returns (RerollChances memory)
    {
        if (assetsRegistry.uniqueWeightsForType(_assetId)[0] == weight) {
            return
                RerollChances(
                    0,
                    _rerollChances.sameWeight + _rerollChances.downgrade,
                    _rerollChances.rarityPlus
                );
        } else if (
            assetsRegistry.uniqueWeightsForType(_assetId)[
                assetsRegistry.uniqueWeightsForType(_assetId).length - 1
            ] == weight
        ) {
            return
                RerollChances(
                    _rerollChances.downgrade,
                    _rerollChances.sameWeight + _rerollChances.rarityPlus,
                    0
                );
        } else {
            return _rerollChances;
        }
    }

    function rerollPrice(uint256 _tokenId, uint256 _assetId) public view returns (uint256 _price) {
        IAssetRegistry.AssetInfo memory _assetTemp = _assetId == 0
            ? scionsData[_tokenId].background
            : (
                _assetId == 1
                    ? scionsData[_tokenId].halo
                    : (
                        _assetId == 2
                            ? scionsData[_tokenId].head
                            : (
                                _assetId == 3
                                    ? scionsData[_tokenId].body
                                    : (
                                        _assetId == 4
                                            ? scionsData[_tokenId].wings
                                            : (
                                                _assetId == 5
                                                    ? scionsData[_tokenId].hands
                                                    : scionsData[_tokenId].sigil
                                            )
                                    )
                            )
                    )
            );

        uint256[] memory _weightsForType = assetsRegistry.uniqueWeightsForType(_assetId);
        uint256 _weightWanted = _weightsForType[
            (assetsRegistry.uniqueWeightsForTypeIndexes(_assetId, _assetTemp.weight) ==
                _weightsForType.length - 1)
                ? assetsRegistry.uniqueWeightsForTypeIndexes(_assetId, _assetTemp.weight)
                : assetsRegistry.uniqueWeightsForTypeIndexes(_assetId, _assetTemp.weight) + 1
        ];
        _price =
            MAX_WEIGHT -
            _assetTemp.weight +
            _weightWanted +
            ((_assetTemp.weight + _weightWanted) / _weightWanted**2);
    }

    function burnForSoul(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");

        soul.safeTransfer(msg.sender, 1 * priceForRarityInSouls);
        _burn(tokenId); // add new burn with scionsData
    }

    // rarity should not be less then it was before
    function rerollCalculate(
        uint256 _randomNumber,
        uint256 _assetId,
        uint256 _tokenId,
        uint256 _price
    ) private {
        uint256 _state = _randomNumber <= _rerollChances.downgrade
            ? 0
            : (
                (_randomNumber > _rerollChances.downgrade &&
                    _randomNumber <= _rerollChances.sameWeight)
                    ? 1
                    : 2
            );

        if (_assetId == 0) {
            handleWeightChange(
                scionsData[_tokenId].background.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 1) {
            handleWeightChange(
                scionsData[_tokenId].halo.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 2) {
            handleWeightChange(
                scionsData[_tokenId].head.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 3) {
            handleWeightChange(
                scionsData[_tokenId].body.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 4) {
            handleWeightChange(
                scionsData[_tokenId].wings.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 5) {
            handleWeightChange(
                scionsData[_tokenId].hands.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 6) {
            handleWeightChange(
                scionsData[_tokenId].sigil.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        }
    }

    function weightChange(
        uint256 _assetId,
        uint256 _assetIndex,
        uint256 _state
    ) private view returns (uint256 _weight) {
        uint256 currentWeight = assetsRegistry.getAssetInfo(_assetId, _assetIndex).weight;

        if (_state == 1) return currentWeight;

        uint256[] memory _weightsForType = assetsRegistry.uniqueWeightsForType(_assetId);

        for (uint256 i = 0; i < _weightsForType.length; i++) {
            if (_weightsForType[i] == currentWeight) {
                if (_state == 0 && i != 0) {
                    currentWeight = _weightsForType[i - 1];
                } else if (_state == 2 && i != _weightsForType.length - 1) {
                    currentWeight = _weightsForType[i + 1];
                }
                break;
            }
        }

        return currentWeight;
    }

    function setWeightChange(
        uint256 _assetId,
        uint256 _assetIndex,
        uint256 _state
    ) private view returns (IAssetRegistry.AssetInfo memory) {
        uint256 currentWeight = weightChange(_assetId, _assetIndex, _state);

        IAssetRegistry.AssetInfo[] memory assetsPerTypePerWeight = assetsRegistry
            .getAssetsPerTypePerWeight(_assetId, currentWeight);

        uint256 _random = RandomGenerator.random(_msgSender(), assetsPerTypePerWeight.length, 0);

        IAssetRegistry.AssetInfo memory result = assetsPerTypePerWeight[_random];

        return result;
    }

    function handleWeightChange(
        uint256 _assetIndex,
        uint256 _assetId,
        uint256 _tokenId,
        uint256 _state,
        uint256 _price
    ) private {
        uint256 _previousWeight;
        uint256 _newWeight;
        string memory _newAsset;

        if (_assetId == 0) {
            _previousWeight = scionsData[_tokenId].background.weight;
            scionsData[_tokenId].background = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].background.weight;
            _newAsset = scionsData[_tokenId].background.asset;
        }

        if (_assetId == 1) {
            _previousWeight = scionsData[_tokenId].halo.weight;
            scionsData[_tokenId].halo = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].halo.weight;
            _newAsset = scionsData[_tokenId].halo.asset;
        }

        if (_assetId == 2) {
            _previousWeight = scionsData[_tokenId].head.weight;
            scionsData[_tokenId].head = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].head.weight;
            _newAsset = scionsData[_tokenId].head.asset;
        }

        if (_assetId == 3) {
            _previousWeight = scionsData[_tokenId].body.weight;
            scionsData[_tokenId].body = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].body.weight;
            _newAsset = scionsData[_tokenId].body.asset;
        }

        if (_assetId == 4) {
            _previousWeight = scionsData[_tokenId].wings.weight;
            scionsData[_tokenId].wings = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].wings.weight;
            _newAsset = scionsData[_tokenId].wings.asset;
        }

        if (_assetId == 5) {
            _previousWeight = scionsData[_tokenId].hands.weight;
            scionsData[_tokenId].hands = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].hands.weight;
            _newAsset = scionsData[_tokenId].hands.asset;
        }

        if (_assetId == 6) {
            _previousWeight = scionsData[_tokenId].sigil.weight;
            scionsData[_tokenId].sigil = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].sigil.weight;
            _newAsset = scionsData[_tokenId].sigil.asset;
        }

        emit Reroll(
            _tokenId,
            _assetId,
            _previousWeight,
            int256(_newWeight),
            _newAsset,
            scionsData[_tokenId],
            _price,
            block.timestamp,
            msg.sender
        );
    }

    function rerollAsset(uint256 tokenId, uint256 assetId) public {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        require(assetId <= 6);
        uint256 _price = rerollPrice(tokenId, assetId);

        keter.safeTransferFrom(msg.sender, address(this), _price * 10**18);
        rerollCalculate(
            RandomGenerator.random(_msgSender(), BP, 0),
            assetId,
            tokenId,
            _price * 10**18
        );
        // requestRandomWords(tokenId, int256(assetId), 0, -1, 2);
    }

    function claimScion(uint256 mintPassId) public {
        require(mintPasses.ownerOf(mintPassId) == msg.sender, "Scion: invalid owner");

        // Burning minting pass
        mintPasses.burn(mintPassId);

        uint256 newTokenId = _tokenIdTracker.current();

        assignAssets(newTokenId, mintPassId);
        _safeMint(msg.sender, newTokenId);

        _tokenIdTracker.increment();

        emit ScionClaimed(
            msg.sender,
            newTokenId,
            mintPassId,
            scionsData[newTokenId],
            block.timestamp
        );
    }

    function assignAssets(uint256 _tokenId, uint256 _mintPassId) internal {
        for (uint256 i; i <= 6; i++) {
            _assignAssetsFromType(i, _tokenId, _mintPassId);
        }
    }

    function _assignAssetsFromType(
        uint256 _assetId,
        uint256 _tokenId,
        uint256 _mintPassId
    ) internal {
        (MintPasses.Class class, uint256 salt) = mintPasses.mintPassInfos(_mintPassId);
        (, , , uint256 bottom, uint256 top) = mintPasses.classLimits(class);

        IAssetRegistry.AssetInfo[] memory assetsPerTypePerWeightRange = assetsRegistry
            .getAssetsPerTypePerWeightRange(_assetId, bottom, top);

        uint256 randomNumber = RandomGenerator.random(
            _msgSender(),
            assetsRegistry.getTotalWeightArray(assetsPerTypePerWeightRange), // total of weight of array
            salt
        );

        emit RandomGenerated(randomNumber);

        uint256 previousWeightSum = 0;
        IAssetRegistry.AssetInfo memory newAsset;

        for (uint256 i; i < assetsPerTypePerWeightRange.length; i++) {
            uint256 newWeightSum = previousWeightSum.add(assetsPerTypePerWeightRange[i].weight);
            if (previousWeightSum <= randomNumber && randomNumber < newWeightSum) {
                newAsset = IAssetRegistry.AssetInfo(
                    assetsPerTypePerWeightRange[i].asset,
                    assetsPerTypePerWeightRange[i].weight,
                    assetsPerTypePerWeightRange[i].name,
                    assetsPerTypePerWeightRange[i].assetIndex
                );
                if (_assetId == 0) {
                    scionsData[_tokenId].background = newAsset;
                }
                if (_assetId == 1) {
                    scionsData[_tokenId].halo = newAsset;
                }
                if (_assetId == 2) {
                    scionsData[_tokenId].head = newAsset;
                }
                if (_assetId == 3) {
                    scionsData[_tokenId].body = newAsset;
                }
                if (_assetId == 4) {
                    scionsData[_tokenId].wings = newAsset;
                }
                if (_assetId == 5) {
                    scionsData[_tokenId].hands = newAsset;
                }
                if (_assetId == 6) {
                    scionsData[_tokenId].sigil = newAsset;
                }
                break;
            }
            previousWeightSum = newWeightSum;
        }
    }
}
