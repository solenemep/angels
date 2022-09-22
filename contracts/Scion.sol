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
import "./MintPasses.sol";


contract Scion is Ownable, ERC721Enumerable {
    // Mint, receives the minting pass NFT, burns it to create a Scion  
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for IERC20;
    
    MintPasses public mintingPass;
    Counters.Counter private _tokenIdTracker;

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    /**
        @dev tokenId to nesting start time (0 = not nesting).
     */
    mapping(uint256 => uint256) private nestingStarted;

    /**
        @dev Cumulative per-token nesting, excluding the current period.
     */
    mapping(uint256 => uint256) private nestingTotal;

    uint256 priceForRarityInSouls = 100e18;
    uint256 BP = 10000;

    uint256 public totalBackgroundAssetsAmount;
    uint256 public totalHaloAssetsAmount;
    uint256 public totalHeadAssetsAmount;
    uint256 public totalBodyAssetsAmount;
    uint256 public totalWingsAssetsAmount;
    uint256 public totalHandsAssetsAmount;
    uint256 public totalSigilAssetsAmount;

    uint256 public totalBackgroundAssetsWeight;
    uint256 public totalHaloAssetsWeight;
    uint256 public totalHeadAssetsWeight;
    uint256 public totalBodyAssetsWeight;
    uint256 public totalWingsAssetsWeight;
    uint256 public totalHandsAssetsWeight;
    uint256 public totalSigilAssetsWeight;

    /**
        @notice Whether nesting is currently allowed.
        @dev If false then nesting is blocked, but unnesting is always allowed.
     */
    bool public nestingOpen = false;

    string private _baseTokenURI;

    IERC20 public soul;
    IERC20 public keter;

    Asset[] public backgroundAssets;
    Asset[] public haloAssets;
    Asset[] public headAssets;
    Asset[] public bodyAssets;
    Asset[] public wingsAssets;
    Asset[] public handsAssets;
    Asset[] public sigilAssets;

    RerollChances public rerollChances;

    struct Asset {
        bool hasIt;
        string asset;
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

    event Reroll(uint256 indexed _tokenId, uint256 indexed _assetId, int256 _previousRarity, int256 _newRarity, uint256 _price, uint256 _timestamp);
    event AssetGenerated(uint256 indexed _tokenId, uint256 indexed _assetId, int256 _rarity, uint256 _timestamp);
    event ScionClaimed(address indexed _user, uint256 indexed _scionId, uint256 mintPassId, uint256 mintPassRarity, Scions _assets, uint256 _timestamp);
    event Nested(uint256 indexed tokenId);
    event Unnested(uint256 indexed tokenId);
    event RandomGenerated(uint256 random);

    constructor(address _mintingPass, address _soul, address _keter, string memory name, string memory symbol, string memory baseTokenURI) ERC721(name, symbol) {
        mintingPass = MintPasses(_mintingPass);
        soul = IERC20(_soul);
        keter = IERC20(_keter);
        _baseTokenURI = baseTokenURI;
    }

    modifier onlyApprovedOrOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == _msgSender() ||
                getApproved(tokenId) == _msgSender(),
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

    function rerollPrice(uint256 _assetId, uint256 _tokenID) public view returns (uint256 _price) {

        uint256 _weightMax = assets[_assetId][0].weight;

        if(_assetId == 0) {
            uint256 _weightWanted = assetsUniqueWeights[_assetId][(scionsData[_tokenID].background.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? scionsData[_tokenID].background.assetIndex : scionsData[_tokenID].background.assetIndex + 1];
            _price = _weightMax - scionsData[_tokenID].background.weight + _weightWanted + ((scionsData[_tokenID].background.weight + _weightWanted) / _weightWanted**2 );
        } 

        if(_assetId == 1) {
            uint256 _weightWanted = assetsUniqueWeights[_assetId][(scionsData[_tokenID].halo.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? scionsData[_tokenID].background.assetIndex : scionsData[_tokenID].background.assetIndex + 1];
            _price = _weightMax - scionsData[_tokenID].background.weight + _weightWanted + ((scionsData[_tokenID].halo.weight + _weightWanted) / _weightWanted**2 );
        }

        if(_assetId == 2) {
            uint256 _weightWanted = assetsUniqueWeights[_assetId][(scionsData[_tokenID].head.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? scionsData[_tokenID].background.assetIndex : scionsData[_tokenID].background.assetIndex + 1];
            _price = _weightMax - scionsData[_tokenID].background.weight + _weightWanted + ((scionsData[_tokenID].head.weight + _weightWanted) / _weightWanted**2 );
        }

        if(_assetId == 3) {
            uint256 _weightWanted = assetsUniqueWeights[_assetId][(scionsData[_tokenID].body.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? scionsData[_tokenID].background.assetIndex : scionsData[_tokenID].background.assetIndex + 1];
            _price = _weightMax - scionsData[_tokenID].background.weight + _weightWanted + ((scionsData[_tokenID].body.weight + _weightWanted) / _weightWanted**2 );
        }

        if(_assetId == 4) {
            uint256 _weightWanted = assetsUniqueWeights[_assetId][(scionsData[_tokenID].wings.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? scionsData[_tokenID].background.assetIndex : scionsData[_tokenID].background.assetIndex + 1];
            _price = _weightMax - scionsData[_tokenID].background.weight + _weightWanted + ((scionsData[_tokenID].wings.weight + _weightWanted) / _weightWanted**2 );
        }

        if(_assetId == 5) {
            uint256 _weightWanted = assetsUniqueWeights[_assetId][(scionsData[_tokenID].hands.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? scionsData[_tokenID].background.assetIndex : scionsData[_tokenID].background.assetIndex + 1];
            _price = _weightMax - scionsData[_tokenID].background.weight + _weightWanted + ((scionsData[_tokenID].hands.weight + _weightWanted) / _weightWanted**2 );
        }

        if(_assetId == 6) {
            uint256 _weightWanted = assetsUniqueWeights[_assetId][(scionsData[_tokenID].sigil.assetIndex == assetsUniqueWeights[_assetId].length - 1) ? scionsData[_tokenID].background.assetIndex : scionsData[_tokenID].background.assetIndex + 1];
            _price = _weightMax - scionsData[_tokenID].background.weight + _weightWanted + ((scionsData[_tokenID].sigil.weight + _weightWanted) / _weightWanted**2 );
        }
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

    function setPriceInSoulsForRarity(uint256 _priceInSouls) external onlyOwner {
        priceForRarityInSouls = _priceInSouls;
    }

    function setRerollChances(RerollChances memory _rerollChances) external onlyOwner {
        rerollChances = _rerollChances;
    }

    function setAssets(uint _assetId, string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length && _names.length == _assets.length);

        assetsTotalAmount[_assetId] = 0;
        uint _previousWeight;

        for(uint256 i; i < _assets.length; i++) {
            assets[_assetId].push(Asset(false, _assets[i], _weights[i], _names[i], i));
            assetsTotalAmount[_assetId]++;

            if(_weights[i] != _previousWeight) {
                _previousWeight = _weights[i];
                assetsUniqueWeights[_assetId].push(_weights[i]);
            }
        }

        assetsTotalWeight[_assetId] = _weights[_assets.length-1];
    }

    function random(uint number, uint _salt) internal view returns(uint){
        return uint(keccak256(abi.encodePacked(block.timestamp, block.difficulty,  
        msg.sender, _salt))) % number;
    }

    function _setAssets(uint _assetId, uint _mintPassId, uint _scionTokenId) internal {
        uint256 previousWeightTemp;
        uint256 salt = mintingPass.mintingPassRandom(_mintPassId);
        uint256 randomNumber = random(assetsTotalWeight[_assetId], salt);
            
        emit RandomGenerated(randomNumber);

        for(uint i; i < assets[_assetId].length; i++) {
            if(randomNumber > previousWeightTemp && randomNumber <= assets[_assetId][i].weight) {
                if(_assetId == 0) {
                    scionsData[_scionTokenId].background = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weight,  assets[_assetId][i].name, i);
                } if(_assetId == 1) {
                    scionsData[_scionTokenId].halo = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weight,  assets[_assetId][i].name, i);
                } if(_assetId == 2) {
                    scionsData[_scionTokenId].head = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weight,  assets[_assetId][i].name, i);
                } if(_assetId == 3) {
                    scionsData[_scionTokenId].body = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weight,  assets[_assetId][i].name, i);
                } if(_assetId == 4) {
                    scionsData[_scionTokenId].wings = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weight,  assets[_assetId][i].name, i);
                } if(_assetId == 5) {
                    scionsData[_scionTokenId].hands = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weight,  assets[_assetId][i].name, i);
                } if(_assetId == 6) {
                    scionsData[_scionTokenId].sigil = Asset(true, assets[_assetId][i].asset,  assets[_assetId][i].weight,  assets[_assetId][i].name, i);
                }

                break;
            }

            previousWeightTemp = assets[_assetId][i].weight;
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
            if(_assetId == 0) {
                handleWeightChange(scionsData[_tokenId].background.assetIndex, _assetId, _tokenId, 
                _randomNumber <= rerollChances.downgrade ? 
                    0 : 
                        ((_randomNumber > rerollChances.downgrade && _randomNumber <= rerollChances.sameWeight) ? 1 : 2), _price
                ); 
            } else if(_assetId == 1) {
                handleWeightChange(scionsData[_tokenId].halo.assetIndex, _assetId, _tokenId, 
                _randomNumber <= rerollChances.downgrade ? 
                    0 : 
                        ((_randomNumber > rerollChances.downgrade && _randomNumber <= rerollChances.sameWeight) ? 1 : 2), _price
                ); 
            } else if(_assetId == 2) {
                handleWeightChange(scionsData[_tokenId].head.assetIndex, _assetId, _tokenId, 
                _randomNumber <= rerollChances.downgrade ? 
                    0 : 
                        ((_randomNumber > rerollChances.downgrade && _randomNumber <= rerollChances.sameWeight) ? 1 : 2), _price
                ); 
            } else if(_assetId == 3) {
                handleWeightChange(scionsData[_tokenId].body.assetIndex, _assetId, _tokenId, 
                _randomNumber <= rerollChances.downgrade ? 
                    0 : 
                        ((_randomNumber > rerollChances.downgrade && _randomNumber <= rerollChances.sameWeight) ? 1 : 2), _price
                ); 
            } else if(_assetId == 4) {
                handleWeightChange(scionsData[_tokenId].wings.assetIndex, _assetId, _tokenId, 
                _randomNumber <= rerollChances.downgrade ? 
                    0 : 
                        ((_randomNumber > rerollChances.downgrade && _randomNumber <= rerollChances.sameWeight) ? 1 : 2), _price
                ); 
            } else if(_assetId == 5) {
                handleWeightChange(scionsData[_tokenId].hands.assetIndex, _assetId, _tokenId, 
                _randomNumber <= rerollChances.downgrade ? 
                    0 : 
                        ((_randomNumber > rerollChances.downgrade && _randomNumber <= rerollChances.sameWeight) ? 1 : 2), _price
                ); 
            } else if(_assetId == 6) {
                handleWeightChange(scionsData[_tokenId].sigil.assetIndex, _assetId, _tokenId, 
                _randomNumber <= rerollChances.downgrade ? 
                    0 : 
                        ((_randomNumber > rerollChances.downgrade && _randomNumber <= rerollChances.sameWeight) ? 1 : 2), _price
                ); 
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

        return assetsTemp[_random];
    }

    function handleWeightChange(uint256 _assetIndex, uint _assetId, uint _tokenId, uint _state, uint _price) internal {

        uint _previousWeight;

        if(_assetId == 0) {  
            _previousWeight = scionsData[_tokenId].background.weight;
            scionsData[_tokenId].background = setWeightChange(_assetId, _assetIndex, _state);
        }

        if(_assetId == 1) {  
            _previousWeight = scionsData[_tokenId].halo.weight;
            scionsData[_tokenId].halo = setWeightChange(_assetId, _assetIndex, _state);
        }

        if(_assetId == 2) {  
            _previousWeight = scionsData[_tokenId].head.weight;
            scionsData[_tokenId].head = setWeightChange(_assetId, _assetIndex, _state);
        }

        if(_assetId == 3) {  
            _previousWeight = scionsData[_tokenId].body.weight;
            scionsData[_tokenId].body = setWeightChange(_assetId, _assetIndex, _state);
        }

        if(_assetId == 4) {  
            _previousWeight = scionsData[_tokenId].wings.weight;
            scionsData[_tokenId].wings = setWeightChange(_assetId, _assetIndex, _state);
        }

        if(_assetId == 5) {  
            _previousWeight = scionsData[_tokenId].hands.weight;
            scionsData[_tokenId].hands = setWeightChange(_assetId, _assetIndex, _state);
        }

        if(_assetId == 6) {  
            _previousWeight = scionsData[_tokenId].sigil.weight;
            scionsData[_tokenId].sigil = setWeightChange(_assetId, _assetIndex, _state);
        }

        emit Reroll(_tokenId, _assetId, int256(_previousWeight), int256(scionsData[_tokenId].background.weight), _price, block.timestamp);
    }
    

    // Shows the minting pass rarity
    // function getMintingPassData(uint256 tokenId) public view returns (Rarity){
    //     return mintingPassRarity[tokenId];
    // }

    function rerollAsset(uint256 tokenId, uint256 assetId) public {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        require(assetId <= 6);
        uint _price = rerollPrice(assetId, tokenId);

        keter.safeTransferFrom(msg.sender, address(this), _price);
        rerollCalculate(random(BP, 0), assetId, tokenId, _price);
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

    function burnForSoul(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");

        soul.safeTransfer(msg.sender, rarity(tokenId) * priceForRarityInSouls);
       _burn(tokenId); // add new burn with scionsData
    }

    function priceInSouls(uint256 tokenId) public view returns (uint256 price) {
        return rarity(tokenId) * priceForRarityInSouls;
    }

    function rarity(uint256 tokenId) public view returns (uint256 _rarity) {

        _rarity += uint256(scionsData[tokenId].background.weight) + 1;
        _rarity += uint256(scionsData[tokenId].halo.weight) + 1;
        _rarity += uint256(scionsData[tokenId].head.weight) + 1;
        _rarity += uint256(scionsData[tokenId].body.weight) + 1;

        _rarity += scionsData[tokenId].wings.hasIt ? uint256(scionsData[tokenId].wings.weight) + 1 : 0;
        _rarity += scionsData[tokenId].hands.hasIt ? uint256(scionsData[tokenId].hands.weight) + 1 : 0;
        _rarity += scionsData[tokenId].sigil.hasIt ? uint256(scionsData[tokenId].sigil.weight) + 1 : 0;
    }
}