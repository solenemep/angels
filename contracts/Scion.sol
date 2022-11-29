//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Registry.sol";

import "./MintPasses.sol";
import "./tokens/Soul.sol";
import "./tokens/Keter.sol";

import "./libraries/RandomGenerator.sol";
import "./interfaces/IAssetRegistry.sol";

contract Scion is OwnableUpgradeable, ERC721Upgradeable, ReentrancyGuardUpgradeable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Soul public soul;
    Keter public keter;
    MintPasses public mintPasses;
    IAssetRegistry public assetsRegistry;

    Counters.Counter private _tokenIdTracker;

    uint256 public constant BP = 10000;
    uint256 private constant MAX_WEIGHT = 2500;

    string private _baseTokenURI;

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
    event ScionBurned(address indexed _user, uint256 indexed _tokenId, uint256 _timestamp);

    function __Scion_init(
        string memory _name,
        string memory _symbol,
        string memory baseTokenURI,
        uint256 _downgrade,
        uint256 _sameWeight,
        uint256 _rarityPlus
    ) external initializer {
        _baseTokenURI = baseTokenURI;
        _rerollChances = RerollChances(_downgrade, _sameWeight, _rarityPlus);

        __Ownable_init();
        __ReentrancyGuard_init();
        __ERC721_init(_name, _symbol);
    }

    function setDependencies(address registryAddress) external onlyOwner {
        assetsRegistry = IAssetRegistry(Registry(registryAddress).getContract("ASSETS"));
        keter = Keter(Registry(registryAddress).getContract("KETER"));
        soul = Soul(Registry(registryAddress).getContract("SOUL"));
        mintPasses = MintPasses(Registry(registryAddress).getContract("MINTPASS"));
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
        IAssetRegistry.AssetInfo memory _assetTemp;
        if (_assetId == 0) {
            _assetTemp = scionsData[_tokenId].background;
        } else if (_assetId == 1) {
            _assetTemp = scionsData[_tokenId].halo;
        } else if (_assetId == 2) {
            _assetTemp = scionsData[_tokenId].head;
        } else if (_assetId == 3) {
            _assetTemp = scionsData[_tokenId].body;
        } else if (_assetId == 4) {
            _assetTemp = scionsData[_tokenId].wings;
        } else if (_assetId == 5) {
            _assetTemp = scionsData[_tokenId].hands;
        } else if (_assetId == 6) {
            _assetTemp = scionsData[_tokenId].sigil;
        }

        uint256[] memory _weightsForType = assetsRegistry.uniqueWeightsForType(_assetId);
        uint256 _actualWeight = _assetTemp.weight;
        uint256 _wantedWeight = _weightsForType[_weightsForType.length - 1];

        for (uint256 i = 0; i < _weightsForType.length - 1; i++) {
            if (_actualWeight == _weightsForType[i]) {
                _wantedWeight = _weightsForType[i + 1];
            }
        }

        _price =
            MAX_WEIGHT -
            (_actualWeight + _wantedWeight) +
            ((_actualWeight - _wantedWeight) / _wantedWeight**2);
    }

    function getPricePerAsset(uint256 tokenId, uint256 assetWeight)
        external
        view
        returns (uint256)
    {
        return getPriceEntireScion(tokenId).mul(assetWeight).div(getScionWeight(tokenId));
    }

    function getPriceEntireScion(uint256 tokenId) public view returns (uint256) {
        return (1250000 * 10**soul.decimals()).div(getScionWeight(tokenId));
    }

    function burnForSoul(uint256 tokenId) external nonReentrant {
        require(ownerOf(tokenId) == _msgSender(), "Scion: invalid owner");

        uint256 price = getPriceEntireScion(tokenId);

        soul.mint(_msgSender(), price);
        _burn(tokenId);
        emit ScionBurned(_msgSender(), tokenId, block.timestamp);
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
        uint256 _newAssetIndex;

        if (_assetId == 0) {
            _previousWeight = scionsData[_tokenId].background.weight;
            scionsData[_tokenId].background = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].background.weight;
            _newAsset = scionsData[_tokenId].background.asset;
            _newAssetIndex = scionsData[_tokenId].background.assetIndex;
        }

        if (_assetId == 1) {
            _previousWeight = scionsData[_tokenId].halo.weight;
            scionsData[_tokenId].halo = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].halo.weight;
            _newAsset = scionsData[_tokenId].halo.asset;
            _newAssetIndex = scionsData[_tokenId].halo.assetIndex;
        }

        if (_assetId == 2) {
            _previousWeight = scionsData[_tokenId].head.weight;
            scionsData[_tokenId].head = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].head.weight;
            _newAsset = scionsData[_tokenId].head.asset;
            _newAssetIndex = scionsData[_tokenId].head.assetIndex;
        }

        if (_assetId == 3) {
            _previousWeight = scionsData[_tokenId].body.weight;
            scionsData[_tokenId].body = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].body.weight;
            _newAsset = scionsData[_tokenId].body.asset;
            _newAssetIndex = scionsData[_tokenId].body.assetIndex;
        }

        if (_assetId == 4) {
            _previousWeight = scionsData[_tokenId].wings.weight;
            scionsData[_tokenId].wings = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].wings.weight;
            _newAsset = scionsData[_tokenId].wings.asset;
            _newAssetIndex = scionsData[_tokenId].wings.assetIndex;
        }

        if (_assetId == 5) {
            _previousWeight = scionsData[_tokenId].hands.weight;
            scionsData[_tokenId].hands = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].hands.weight;
            _newAsset = scionsData[_tokenId].hands.asset;
            _newAssetIndex = scionsData[_tokenId].hands.assetIndex;
        }

        if (_assetId == 6) {
            _previousWeight = scionsData[_tokenId].sigil.weight;
            scionsData[_tokenId].sigil = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].sigil.weight;
            _newAsset = scionsData[_tokenId].sigil.asset;
            _newAssetIndex = scionsData[_tokenId].sigil.assetIndex;
        }

        if (_assetIndex != _newAssetIndex) {
            emit Reroll(
                _tokenId,
                _assetId,
                _previousWeight,
                int256(_newWeight),
                _newAsset,
                scionsData[_tokenId],
                _price,
                block.timestamp,
                _msgSender()
            );
        }
    }

    function rerollAsset(uint256 tokenId, uint256 assetId) public {
        require(ownerOf(tokenId) == _msgSender(), "Scion: invalid owner");
        require(assetId <= 6);
        uint256 _price = rerollPrice(tokenId, assetId);

        keter.transferFrom(_msgSender(), address(this), _price * 10**18);
        rerollCalculate(
            RandomGenerator.random(_msgSender(), BP, 0),
            assetId,
            tokenId,
            _price * 10**18
        );
    }

    function claimScion(uint256 mintPassId) public nonReentrant {
        require(mintPasses.ownerOf(mintPassId) == _msgSender(), "Scion: invalid owner");

        // Burning minting pass
        mintPasses.burn(mintPassId);

        uint256 newTokenId = _tokenIdTracker.current();

        assignAssets(newTokenId, mintPassId);
        _safeMint(_msgSender(), newTokenId);

        _tokenIdTracker.increment();

        emit ScionClaimed(
            _msgSender(),
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
                } else if (_assetId == 1) {
                    scionsData[_tokenId].halo = newAsset;
                } else if (_assetId == 2) {
                    scionsData[_tokenId].head = newAsset;
                } else if (_assetId == 3) {
                    scionsData[_tokenId].body = newAsset;
                } else if (_assetId == 4) {
                    scionsData[_tokenId].wings = newAsset;
                } else if (_assetId == 5) {
                    scionsData[_tokenId].hands = newAsset;
                } else if (_assetId == 6) {
                    scionsData[_tokenId].sigil = newAsset;
                }
                break;
            }
            previousWeightSum = newWeightSum;
        }
    }

    function getScionWeight(uint256 _tokenId) public view returns (uint256 totalWeight) {
        Scions memory scion = scionsData[_tokenId];

        totalWeight =
            scion.background.weight +
            scion.halo.weight +
            scion.head.weight +
            scion.body.weight;

        if (scion.wings.weight != 1000) {
            totalWeight += scion.wings.weight;
        }
        if (scion.hands.weight != 1000) {
            totalWeight += scion.hands.weight;
        }
        if (scion.sigil.weight != 1000) {
            totalWeight += scion.sigil.weight;
        }
    }
}
