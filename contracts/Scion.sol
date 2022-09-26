//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "./MintPasses.sol";


contract Scion is Ownable, ERC721Enumerable {
    // Mint, receives the minting pass NFT, burns it to create a Scion
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    MintPasses public mintingPass;
    Counters.Counter private _tokenIdTracker;

    uint256 public constant priceForRarityInSouls = 100e18;
    uint256 public constant BP = 10000;
    uint256 private constant MAX_WEIGHT = 2500;

    string private _baseTokenURI;

    IERC20 public soul;
    IERC20 public keter;

    RerollChances private _rerollChances;

    struct Asset {
        bool hasIt;
        string asset;
        uint256 weightSum;
        uint256 weight;
        string name;
        uint256 assetIndex;
    }

    struct Scions {
        // Mandatory
        Asset background;
        Asset halo;
        Asset head;
        Asset body;
        // Optional
        Asset wings;
        Asset hands;
        Asset sigil;
    }

    struct RerollChances {
        uint256 downgrade;
        uint256 sameWeight;
        uint256 rarityPlus;
    }

    mapping(uint256 => Scions) public scionsData;
    mapping(uint256 => Asset[]) public assets;
    mapping(uint256 => uint256[]) public assetsUniqueWeights;
    mapping(uint256 => uint256) public assetsTotalWeight;
    mapping(uint256 => uint256) public assetsTotalAmount;

    event Reroll(uint256 indexed _tokenId, uint256 indexed _assetId, uint256 _previousRarity, int256 _newRarity, string _newAsset, Scions _assets, uint256 _price, uint256 _timestamp, address indexed _user);
    event AssetGenerated(uint256 indexed _tokenId, uint256 indexed _assetId, int256 _rarity, uint256 _timestamp);
    event ScionClaimed(address indexed _user, uint256 indexed _scionId, uint256 mintPassId, uint256 mintPassRarity, Scions _assets, uint256 _timestamp);
    event Nested(uint256 indexed tokenId);
    event Unnested(uint256 indexed tokenId);
    event RandomGenerated(uint256 random);

    constructor(address _mintingPass, address _soul, address _keter, string memory name, string memory symbol, string memory baseTokenURI, uint256 _downgrade, uint256 _sameWeight, uint256 _rarityPlus) ERC721(name, symbol) {
        mintingPass = MintPasses(_mintingPass);
        soul = IERC20(_soul);
        keter = IERC20(_keter);
        _baseTokenURI = baseTokenURI;

        _rerollChances = RerollChances(_downgrade, _sameWeight, _rarityPlus);
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

    function rerollChances(uint256 _assetId, uint256 weight) public view returns (RerollChances memory) {
        if(assetsUniqueWeights[_assetId][0] == weight) {
            return RerollChances(0, _rerollChances.sameWeight + _rerollChances.downgrade, _rerollChances.rarityPlus);
        } else if(assetsUniqueWeights[_assetId][assetsUniqueWeights[_assetId].length - 1] == weight) {
            return RerollChances(_rerollChances.downgrade, _rerollChances.sameWeight + _rerollChances.rarityPlus, 0);
        } else {
            return _rerollChances;
        }
    }

    function rerollPrice(uint256 _assetId, uint256 _tokenID) public view returns (uint256 _price) {
        Asset memory _assetTemp = _assetId == 0 ? scionsData[_tokenID].background :
            (_assetId == 1 ? scionsData[_tokenID].halo :
                (_assetId == 2 ? scionsData[_tokenID].head :
                    (_assetId == 3 ? scionsData[_tokenID].body :
                        (_assetId == 4 ? scionsData[_tokenID].wings :
                            (_assetId == 5 ? scionsData[_tokenID].hands :
                                scionsData[_tokenID].sigil)))));

        uint256 _weightWanted = assetsUniqueWeights[_assetId][(_assetTemp.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? _assetTemp.assetIndex : _assetTemp.assetIndex + 1];
        _price = MAX_WEIGHT - _assetTemp.weight + _weightWanted + ((_assetTemp.weight + _weightWanted) / _weightWanted**2 );
    }

    function setAssets(uint _assetId, string[] memory _assets, uint256[] memory _weightSum, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length && _names.length == _assets.length && _weightSum.length == _assets.length);

        assetsTotalAmount[_assetId] = 0;
        uint _previousWeight;

        for(uint256 i; i < _assets.length; i++) {
            assets[_assetId].push(Asset(false, _assets[i], _weightSum[i], _weights[i], _names[i], i));
            assetsTotalAmount[_assetId]++;

            if(_weights[i] != _previousWeight) {
                _previousWeight = _weights[i];
                assetsUniqueWeights[_assetId].push(_weights[i]);
            }
        }

        assetsTotalWeight[_assetId] = _weightSum[_assets.length-1];
    }

    function random(uint number, uint _salt) private view returns(uint){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty,
        msg.sender, _salt))) % number;
    }

    function _setAssets(uint _assetId, uint _mintPassId, uint _scionTokenId) private {
        uint256 previousWeightTemp;
        uint256 salt = mintingPass.mintingPassRandom(_mintPassId);
        uint256 randomNumber = random(assetsTotalWeight[_assetId], salt);

        emit RandomGenerated(randomNumber);

        for(uint i; i < assets[_assetId].length; i++) {
            if(randomNumber > previousWeightTemp && randomNumber <= assets[_assetId][i].weightSum) {
                if(_assetId == 0) {
                    scionsData[_scionTokenId].background = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weightSum, assets[_assetId][i].weight, assets[_assetId][i].name, i);
                } if(_assetId == 1) {
                    scionsData[_scionTokenId].halo = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weightSum, assets[_assetId][i].weight, assets[_assetId][i].name, i);
                } if(_assetId == 2) {
                    scionsData[_scionTokenId].head = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weightSum, assets[_assetId][i].weight, assets[_assetId][i].name, i);
                } if(_assetId == 3) {
                    scionsData[_scionTokenId].body = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weightSum, assets[_assetId][i].weight, assets[_assetId][i].name, i);
                } if(_assetId == 4) {
                    scionsData[_scionTokenId].wings = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weightSum, assets[_assetId][i].weight, assets[_assetId][i].name, i);
                } if(_assetId == 5) {
                    scionsData[_scionTokenId].hands = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weightSum, assets[_assetId][i].weight, assets[_assetId][i].name, i);
                } if(_assetId == 6) {
                    scionsData[_scionTokenId].sigil = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weightSum, assets[_assetId][i].weight, assets[_assetId][i].name, i);
                }

                break;
            }

            previousWeightTemp = assets[_assetId][i].weightSum;
        }
    }

    function defineAssets(
        uint256 scionTokenId,
        uint256 mintPassId,
        int256 mintPassRarity
    ) internal {
        // Mint when I get the callback
            int256 _rarity = mintPassRarity;

            for(uint i; i <= 6; i++) {
                _setAssets(i, mintPassId, scionTokenId);
            }

            emit ScionClaimed(msg.sender, scionTokenId, mintPassId, uint256(_rarity), scionsData[scionTokenId], block.timestamp);
    }

    // rarity should not be less then it was before
    function rerollCalculate(uint256 _randomNumber, uint256 _assetId, uint256 _tokenId, uint256 _price) private {
            uint256 _state = _randomNumber <= _rerollChances.downgrade ?
                    0 :
                        ((_randomNumber > _rerollChances.downgrade && _randomNumber <= _rerollChances.sameWeight) ? 1 : 2);

            if(_assetId == 0) {
                handleWeightChange(scionsData[_tokenId].background.assetIndex, _assetId, _tokenId, _state, _price);
            } else if(_assetId == 1) {
                handleWeightChange(scionsData[_tokenId].halo.assetIndex, _assetId, _tokenId, _state, _price);
            } else if(_assetId == 2) {
                handleWeightChange(scionsData[_tokenId].head.assetIndex, _assetId, _tokenId, _state, _price);
            } else if(_assetId == 3) {
                handleWeightChange(scionsData[_tokenId].body.assetIndex, _assetId, _tokenId, _state, _price);
            } else if(_assetId == 4) {
                handleWeightChange(scionsData[_tokenId].wings.assetIndex, _assetId, _tokenId, _state, _price);
            } else if(_assetId == 5) {
                handleWeightChange(scionsData[_tokenId].hands.assetIndex, _assetId, _tokenId, _state, _price);
            } else if(_assetId == 6) {
                handleWeightChange(scionsData[_tokenId].sigil.assetIndex, _assetId, _tokenId, _state, _price);
            }
    }

    function weightChange(uint _assetId, uint256 _assetIndex, uint _state) private view returns (uint _weight) {
        uint256 currentWeight = assets[_assetId][_assetIndex].weight;

        if(_state == 1) return currentWeight;

        for(uint i = 0; i < assetsUniqueWeights[_assetId].length; i++) {
            if(assetsUniqueWeights[_assetId][i] == currentWeight) {
                if(_state == 0 && i != 0) {
                    currentWeight = assetsUniqueWeights[_assetId][i-1];
                } else if(_state == 2 && i != assetsUniqueWeights[_assetId].length-1) {
                    currentWeight = assetsUniqueWeights[_assetId][i+1];
                }
                break;
            }
        }

        return currentWeight;
    }

    function setWeightChange(uint _assetId, uint256 _assetIndex, uint _state) private view returns(Asset memory) {
        uint256 currentWeight = weightChange(_assetId, _assetIndex, _state);
        uint256 count;

        for(uint i = 0; i < assets[_assetId].length; i++) {
            if(assets[_assetId][i].weight == currentWeight) {
                count++;
            }
        }

        Asset[] memory assetsTemp = new Asset[](count);
        uint256 index;

        for(uint i = 0; i < assets[_assetId].length; i++) {
            if(assets[_assetId][i].weight == currentWeight) {
                assetsTemp[index] = assets[_assetId][i];
                index++;
            }
        }

        uint256 _random = random(count, 0);
        Asset memory result = assetsTemp[_random];
        result.hasIt = true;
        
        return result;
    }

    function handleWeightChange(uint256 _assetIndex, uint _assetId, uint _tokenId, uint _state, uint _price) private {
        uint _previousWeight;
        uint _newWeight;
        string memory _newAsset;

        if(_assetId == 0) {
            _previousWeight = scionsData[_tokenId].background.weight;
            scionsData[_tokenId].background = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].background.weight;
            _newAsset = scionsData[_tokenId].background.asset;
        }

        if(_assetId == 1) {
            _previousWeight = scionsData[_tokenId].halo.weight;
            scionsData[_tokenId].halo = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].halo.weight;
            _newAsset = scionsData[_tokenId].halo.asset;
        }

        if(_assetId == 2) {
            _previousWeight = scionsData[_tokenId].head.weight;
            scionsData[_tokenId].head = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].head.weight;
            _newAsset = scionsData[_tokenId].head.asset;
        }

        if(_assetId == 3) {
            _previousWeight = scionsData[_tokenId].body.weight;
            scionsData[_tokenId].body = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].body.weight;
            _newAsset = scionsData[_tokenId].body.asset;
        }

        if(_assetId == 4) {
            _previousWeight = scionsData[_tokenId].wings.weight;
            scionsData[_tokenId].wings = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].wings.weight;
            _newAsset = scionsData[_tokenId].wings.asset;
        }

        if(_assetId == 5) {
            _previousWeight = scionsData[_tokenId].hands.weight;
            scionsData[_tokenId].hands = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].hands.weight;
            _newAsset = scionsData[_tokenId].hands.asset;
        }

        if(_assetId == 6) {
            _previousWeight = scionsData[_tokenId].sigil.weight;
            scionsData[_tokenId].sigil = setWeightChange(_assetId, _assetIndex, _state);
            _newWeight = scionsData[_tokenId].sigil.weight;
            _newAsset = scionsData[_tokenId].sigil.asset;
        }

        emit Reroll(_tokenId, _assetId, _previousWeight, int256(_newWeight), _newAsset, scionsData[_tokenId], _price, block.timestamp, msg.sender);
    }

    // Shows the minting pass rarity
    // function getMintingPassData(uint256 tokenId) public view returns (Rarity){
    //     return mintingPassRarity[tokenId];
    // }

    function rerollAsset(uint256 tokenId, uint256 assetId) public {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        require(assetId <= 6);
        uint _price = rerollPrice(assetId, tokenId);

        keter.safeTransferFrom(msg.sender, address(this), _price * 10**18);
        rerollCalculate(random(BP, 0), assetId, tokenId, _price * 10**18);
        //requestRandomWords(tokenId, int256(assetId), 0, -1, 2);
    }

    function claimScion(uint256 tokenId) public {
        require(mintingPass.ownerOf(tokenId) == msg.sender, "Scion: invalid owner");

        // Burning minting pass
        mintingPass.burn(tokenId);

        defineAssets(_tokenIdTracker.current(), tokenId, 0);

        _safeMint(msg.sender, _tokenIdTracker.current());

        _tokenIdTracker.increment();
    }
}
