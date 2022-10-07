//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./MintPasses.sol";
import "./IAssetRegistry.sol";

contract Scion is Ownable, ERC721Enumerable {
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    IAssetRegistry public assetsRegistry;
    MintPasses public mintingPass;
    Counters.Counter private _tokenIdTracker;

    uint256 public constant PRICE_FOR_RARITY_IN_SOULS = 100e18;
    uint256 public constant BP = 10000;
    uint256 private constant _MAX_WEIGHT = 2500;

    string private _baseTokenURI;

    IERC20 public soul;
    IERC20 public keter;

    RerollChances private _rerollChances;

    struct Scions {
        // Mandatory
        IAssetRegistry.Asset background;
        IAssetRegistry.Asset halo;
        IAssetRegistry.Asset head;
        IAssetRegistry.Asset body;
        // Optional
        IAssetRegistry.Asset wings;
        IAssetRegistry.Asset hands;
        IAssetRegistry.Asset sigil;
    }

    struct RerollChances {
        uint256 downgrade;
        uint256 sameWeight;
        uint256 rarityPlus;
    }

    mapping(uint256 => Scions) public scionsData;

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
        uint256 indexed _scionId,
        uint256 mintPassId,
        Scions _assets,
        uint256 _timestamp
    );
    event RandomGenerated(uint256 random);

    constructor(
        address _mintingPass,
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
        mintingPass = MintPasses(_mintingPass);
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

    function rerollPrice(uint256 _assetId, uint256 _tokenID) public view returns (uint256 _price) {
        IAssetRegistry.Asset memory _assetTemp = _assetId == 0
            ? scionsData[_tokenID].background
            : (
                _assetId == 1
                    ? scionsData[_tokenID].halo
                    : (
                        _assetId == 2
                            ? scionsData[_tokenID].head
                            : (
                                _assetId == 3
                                    ? scionsData[_tokenID].body
                                    : (
                                        _assetId == 4
                                            ? scionsData[_tokenID].wings
                                            : (
                                                _assetId == 5
                                                    ? scionsData[_tokenID].hands
                                                    : scionsData[_tokenID].sigil
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
            _MAX_WEIGHT -
            _assetTemp.weight +
            _weightWanted +
            ((_assetTemp.weight + _weightWanted) / _weightWanted**2);
    }

    function burnForSoul(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");

        soul.safeTransfer(msg.sender, 1 * PRICE_FOR_RARITY_IN_SOULS);
        _burn(tokenId); // add new burn with scionsData
    }

    function priceInSouls() public pure returns (uint256 price) {
        return 1 * PRICE_FOR_RARITY_IN_SOULS;
    }

    function _random(uint256 _limit, uint256 _salt) internal view returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, _salt))
            ) % _limit;
    }

    // rarity should not be less then it was before
    function _rerollCalculate(
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
            _handleWeightChange(
                scionsData[_tokenId].background.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 1) {
            _handleWeightChange(
                scionsData[_tokenId].halo.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 2) {
            _handleWeightChange(
                scionsData[_tokenId].head.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 3) {
            _handleWeightChange(
                scionsData[_tokenId].body.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 4) {
            _handleWeightChange(
                scionsData[_tokenId].wings.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 5) {
            _handleWeightChange(
                scionsData[_tokenId].hands.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        } else if (_assetId == 6) {
            _handleWeightChange(
                scionsData[_tokenId].sigil.assetIndex,
                _assetId,
                _tokenId,
                _state,
                _price
            );
        }
    }

    function _weightChange(
        uint256 _assetId,
        uint256 _assetIndex,
        uint256 _state
    ) private view returns (uint256 _weight) {
        uint256 currentWeight = assetsRegistry.assetsForType(_assetId)[_assetIndex].weight;

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

    function _setWeightChange(
        uint256 _assetId,
        uint256 _assetIndex,
        uint256 _state
    ) private view returns (IAssetRegistry.Asset memory) {
        uint256 currentWeight = _weightChange(_assetId, _assetIndex, _state);
        uint256 count;
        IAssetRegistry.Asset[] memory _assetsOfType = assetsRegistry.assetsForType(_assetId);
        for (uint256 i = 0; i < _assetsOfType.length; i++) {
            if (_assetsOfType[i].weight == currentWeight) {
                count++;
            }
        }

        IAssetRegistry.Asset[] memory assetsTemp = new IAssetRegistry.Asset[](count);
        uint256 index;

        for (uint256 i = 0; i < _assetsOfType.length; i++) {
            if (_assetsOfType[i].weight == currentWeight) {
                assetsTemp[index] = _assetsOfType[i];
                index++;
            }
        }

        uint256 _randomNumber = _random(count, 0);
        IAssetRegistry.Asset memory result = assetsTemp[_randomNumber];
        result.hasIt = true;

        return result;
    }

    function _handleWeightChange(
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
            scionsData[_tokenId].background = _setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].background.weight;
            _newAsset = scionsData[_tokenId].background.asset;
        }

        if (_assetId == 1) {
            _previousWeight = scionsData[_tokenId].halo.weight;
            scionsData[_tokenId].halo = _setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].halo.weight;
            _newAsset = scionsData[_tokenId].halo.asset;
        }

        if (_assetId == 2) {
            _previousWeight = scionsData[_tokenId].head.weight;
            scionsData[_tokenId].head = _setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].head.weight;
            _newAsset = scionsData[_tokenId].head.asset;
        }

        if (_assetId == 3) {
            _previousWeight = scionsData[_tokenId].body.weight;
            scionsData[_tokenId].body = _setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].body.weight;
            _newAsset = scionsData[_tokenId].body.asset;
        }

        if (_assetId == 4) {
            _previousWeight = scionsData[_tokenId].wings.weight;
            scionsData[_tokenId].wings = _setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].wings.weight;
            _newAsset = scionsData[_tokenId].wings.asset;
        }

        if (_assetId == 5) {
            _previousWeight = scionsData[_tokenId].hands.weight;
            scionsData[_tokenId].hands = _setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].hands.weight;
            _newAsset = scionsData[_tokenId].hands.asset;
        }

        if (_assetId == 6) {
            _previousWeight = scionsData[_tokenId].sigil.weight;
            scionsData[_tokenId].sigil = _setWeightChange(_assetId, _assetIndex, _state);
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

    // Shows the minting pass rarity
    // function getMintingPassData(uint256 tokenId) public view returns (Rarity){
    //     return mintingPassRarity[tokenId];
    // }

    function rerollAsset(uint256 tokenId, uint256 assetId) public {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        require(assetId <= 6);
        uint256 _price = rerollPrice(assetId, tokenId);

        keter.safeTransferFrom(msg.sender, address(this), _price * 10**18);
        _rerollCalculate(_random(BP, 0), assetId, tokenId, _price * 10**18);
        //requestRandomWords(tokenId, int256(assetId), 0, -1, 2);
    }

    function claimScion(uint256 tokenId) public {
        require(mintingPass.ownerOf(tokenId) == msg.sender, "Scion: invalid owner");

        // Burning minting pass
        mintingPass.burn(tokenId);

        _assignAssets(_tokenIdTracker.current(), tokenId);

        _safeMint(msg.sender, _tokenIdTracker.current());

        _tokenIdTracker.increment();
    }

    function _assignAssets(uint256 scionTokenId, uint256 mintPassId) internal {
        for (uint256 i; i <= 6; i++) {
            _assignAssetsFromType(i, mintPassId, scionTokenId);
        }
        emit ScionClaimed(
            msg.sender,
            scionTokenId,
            mintPassId,
            scionsData[scionTokenId],
            block.timestamp
        );
    }

    function _assignAssetsFromType(
        uint256 _assetId,
        uint256 _mintPassId,
        uint256 _scionTokenId
    ) internal {
        uint256 previousWeightTemp;
        uint256 salt = mintingPass.mintingPassRandom(_mintPassId);
        uint256 randomNumber = _random(assetsRegistry.totalWeightForType(_assetId), salt);

        emit RandomGenerated(randomNumber);

        IAssetRegistry.Asset[] memory _assetsOfType = assetsRegistry.assetsForType(_assetId);
        for (uint256 i; i < _assetsOfType.length; i++) {
            if (randomNumber > previousWeightTemp && randomNumber <= _assetsOfType[i].weightSum) {
                IAssetRegistry.Asset memory _newAsset = IAssetRegistry.Asset(
                    true,
                    _assetsOfType[i].asset,
                    _assetsOfType[i].weightSum,
                    _assetsOfType[i].weight,
                    _assetsOfType[i].name,
                    i
                );
                if (_assetId == 0) {
                    scionsData[_scionTokenId].background = _newAsset;
                }
                if (_assetId == 1) {
                    scionsData[_scionTokenId].halo = _newAsset;
                }
                if (_assetId == 2) {
                    scionsData[_scionTokenId].head = _newAsset;
                }
                if (_assetId == 3) {
                    scionsData[_scionTokenId].body = _newAsset;
                }
                if (_assetId == 4) {
                    scionsData[_scionTokenId].wings = _newAsset;
                }
                if (_assetId == 5) {
                    scionsData[_scionTokenId].hands = _newAsset;
                }
                if (_assetId == 6) {
                    scionsData[_scionTokenId].sigil = _newAsset;
                }
                break;
            }

            previousWeightTemp = _assetsOfType[i].weight;
        }
    }
}
