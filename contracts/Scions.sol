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


contract Scion is Ownable, ERC721Enumerable, VRFConsumerBaseV2 {
    // Mint, receives the minting pass NFT, burns it to create a Scion  
    using Counters for Counters.Counter;
    using Strings for uint256;
    using SafeERC20 for IERC20;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;
    
    MintPasses public mintingPass;
    Counters.Counter private _tokenIdTracker;

    VRFCoordinatorV2Interface COORDINATOR;
    LinkTokenInterface LINKTOKEN;

    // Your subscription ID.
    uint64 s_subscriptionId;

    bytes32 keyHash;

    uint32 callbackGasLimit = 500000;
    uint256 rerollPrice = 1e18;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    IERC20 public soul;
    IERC20 public keter;

    enum Rarity {
        COMMON,
        RARE,
        EPIC,
        EPIC_RARE,
        LEGENDARY,
        MYSTIC, 
        EXTRA_CELESTIAL
    }

    mapping (uint256 => Rarity) public scionRarity;
    mapping(uint256 => uint256) private requestIdToTokenId;
    mapping(uint256 => int256) private requestIdToAssetId;
    mapping(uint256 => bool) private requestIdExists;
    mapping(uint256 => int256) private requestIdToMintPassRarity;
    mapping (uint => mapping (uint => AssetRarity)) private rarityTemp;

    // ULTRA_RARE: Only bought with $KETER = yield scions
    enum AssetRarity {
        COMMON,
        RARE,
        EPIC_RARE,
        LEGENDARY,
        MYSTIC,
        EXTRA_CELESTIAL
    }

    enum ScionRarity {
        COMMON,
        RARE,
        EPIC_RARE,
        LEGENDARY,
        MYSTIC, 
        EXTRA_CELESTIAL
    }

    // they have a cost in Souls
    struct Asset {
        bool hasIt;
        AssetRarity rarity;
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

    mapping(uint256 => Scions) public scionsData;
    // Burn creates FT Souls

    constructor(uint64 subscriptionId, address vrfCoordinator, address link, bytes32 _keyHash, address _mintingPass, address _soul, address _keter) ERC721("SCION", "SCION") VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        keyHash = _keyHash;
        s_subscriptionId = subscriptionId;
        mintingPass = MintPasses(_mintingPass);
        soul = IERC20(_soul);
        keter = IERC20(_keter);
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

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint256 mintPassTokenId, int256 assetId, int256 mintPassRarity, uint256 numWords) internal returns (uint256 s_requestId) {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            uint32(numWords)
        );

        requestIdToAssetId[s_requestId] = assetId;
        requestIdToMintPassRarity[s_requestId] = mintPassRarity;
        requestIdToTokenId[s_requestId] = mintPassTokenId;
        requestIdExists[s_requestId] = true;
    }
    
    function fulfillRandomWords(
        uint256 requestId, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        // Mint when I get the callback 
        if(requestIdExists[requestId]) {
            if(requestIdToMintPassRarity[requestId] >= 0) {
                uint256 randomNumber = (randomWords[0] % 100) + 1;
                uint256 assetsAmount = randomWords.length;
                uint256 nonCommonAmount;
                
                if(randomNumber < 50) {
                    assetsAmount -= 1;
                } 

                for(uint i = 1; i < assetsAmount; i++) {
                    if(nonCommonAmount == 2) {
                        rarityTemp[requestIdToTokenId[requestId]][i - 1] = AssetRarity.COMMON;
                        //scionsData[requestIdToTokenId[requestId]][i - 1] = (true, AssetRarity.COMMON);
                        continue;
                    }

                    AssetRarity rarity;

                    if(requestIdToMintPassRarity[requestId] == 0) {
                        rarity = commonMintPassChances(randomWords[i] % 100);
                    } else if(requestIdToMintPassRarity[requestId] == 1) {
                        rarity = rareMintPassChances(randomWords[i] % 100);
                    } else if(requestIdToMintPassRarity[requestId] == 2 || requestIdToMintPassRarity[requestId] == 3) {
                        rarity = epicRareMintPassChances(randomWords[i] % 100);
                    }
                    

                    if(rarity != AssetRarity.COMMON) {
                        nonCommonAmount++;
                    }

                    rarityTemp[requestIdToTokenId[requestId]][i - 1] = rarity;
                    //scionsData[requestIdToTokenId[requestId]][i - 1] = (true, rarity);
                }

                scionsData[requestIdToTokenId[requestId]].background = Asset(true, rarityTemp[requestIdToTokenId[requestId]][0]);
                scionsData[requestIdToTokenId[requestId]].halo = Asset(true, rarityTemp[requestIdToTokenId[requestId]][1]);
                scionsData[requestIdToTokenId[requestId]].head = Asset(true, rarityTemp[requestIdToTokenId[requestId]][2]);
                scionsData[requestIdToTokenId[requestId]].body = Asset(true, rarityTemp[requestIdToTokenId[requestId]][3]);
                
                if(assetsAmount == 5) {
                    scionsData[requestIdToTokenId[requestId]].wings = Asset(true, rarityTemp[requestIdToTokenId[requestId]][3]);
                }
            } else if(requestIdToAssetId[requestId] >= 0) {
                uint256 randomNumber = (randomWords[0] % 100);
                if(requestIdToAssetId[requestId] >= 4) {
                    if(requestIdToAssetId[requestId] == 4 && scionsData[requestIdToTokenId[requestId]].wings.hasIt) {
                        rerollCalculate(randomWords[1] % 100, uint256(requestIdToAssetId[requestId]), requestIdToTokenId[requestId], scionsData[requestIdToTokenId[requestId]].wings.rarity);
                    } 

                    if(requestIdToAssetId[requestId] == 5 && scionsData[requestIdToTokenId[requestId]].hands.hasIt) {
                        rerollCalculate(randomWords[1] % 100, uint256(requestIdToAssetId[requestId]), requestIdToTokenId[requestId], scionsData[requestIdToTokenId[requestId]].hands.rarity);
                    }

                    if(requestIdToAssetId[requestId] == 6 && scionsData[requestIdToTokenId[requestId]].sigil.hasIt) {
                        rerollCalculate(randomWords[1] % 100, uint256(requestIdToAssetId[requestId]), requestIdToTokenId[requestId], scionsData[requestIdToTokenId[requestId]].sigil.rarity);
                    }

                    if(randomNumber > 95) {
                        rerollCalculate(randomWords[1] % 100, uint256(requestIdToAssetId[requestId]), requestIdToTokenId[requestId], AssetRarity.COMMON);
                    }
                }
            }

            requestIdExists[requestId] = false;
        }
    }

    // rarity should not be less then it was before
    function rerollCalculate(uint256 randomNumber, uint256 assetId, uint256 tokenId, AssetRarity _previousRarity) private {
        if(randomNumber < 70) {
            if(assetId == 4) {
                scionsData[tokenId].wings = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.RARE) ? _previousRarity : AssetRarity.RARE);
            }

            if(assetId == 5) {
                scionsData[tokenId].hands = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.RARE) ? _previousRarity : AssetRarity.RARE);
            }

            if(assetId == 6) {
                scionsData[tokenId].sigil = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.RARE) ? _previousRarity : AssetRarity.RARE);
            }
            
        } else if(randomNumber >= 70 && randomNumber <= 95) {
            if(assetId == 4) {
                scionsData[tokenId].wings = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.EPIC_RARE) ? _previousRarity : AssetRarity.EPIC_RARE);
            }

            if(assetId == 5) {
                scionsData[tokenId].hands = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.EPIC_RARE) ? _previousRarity : AssetRarity.EPIC_RARE);
            }

            if(assetId == 6) {
                scionsData[tokenId].sigil = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.EPIC_RARE) ? _previousRarity : AssetRarity.EPIC_RARE);
            }
        } else {
            if(assetId == 4) {
                scionsData[tokenId].wings = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.LEGENDARY) ? _previousRarity : AssetRarity.LEGENDARY);
            }

            if(assetId == 5) {
                scionsData[tokenId].hands = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.LEGENDARY) ? _previousRarity : AssetRarity.LEGENDARY);
            }

            if(assetId == 6) {
                scionsData[tokenId].sigil = Asset(true, uint256(_previousRarity) > uint256(AssetRarity.LEGENDARY) ? _previousRarity : AssetRarity.LEGENDARY);
            }
        }
    }

    // Shows the minting pass rarity
    // function getMintingPassData(uint256 tokenId) public view returns (Rarity){
    //     return mintingPassRarity[tokenId];
    // }

    function rerollAsset(uint256 tokenId, uint256 assetId) public {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        require(assetId <= 6);

        keter.safeTransferFrom(msg.sender, address(this), rerollPrice);
        requestRandomWords(tokenId, int256(assetId), -1, 1);
    }

    function claimScion(uint256 tokenId) public {
        require(mintingPass.ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        
        int256 rarity = int256(uint256(mintingPass.getMintingPassData(tokenId)));

        // Burning minting pass
        mintingPass.burn(tokenId);

        if(rarity == 0) {
            requestRandomWords(_tokenIdTracker.current(), -1, rarity, 6);
        } else if(rarity == 1) {
            requestRandomWords(_tokenIdTracker.current(), -1, rarity, 6);  
        } else if(rarity == 2) {
            requestRandomWords(_tokenIdTracker.current(), -1, rarity, 6);  
        } else if(rarity == 3) {
            //legendaryMintPassChances();
        } else if(rarity == 4) {
            scionsData[_tokenIdTracker.current()].background = Asset(true, AssetRarity.LEGENDARY);
            scionsData[_tokenIdTracker.current()].halo = Asset(true, AssetRarity.LEGENDARY);
            scionsData[_tokenIdTracker.current()].head = Asset(true, AssetRarity.LEGENDARY);
            scionsData[_tokenIdTracker.current()].body = Asset(true, AssetRarity.LEGENDARY);
            scionsData[_tokenIdTracker.current()].wings = Asset(true, AssetRarity.LEGENDARY);
            scionsData[_tokenIdTracker.current()].hands = Asset(true, AssetRarity.LEGENDARY);
        } else if(rarity == 5) {
            scionsData[_tokenIdTracker.current()].background = Asset(true, AssetRarity.EXTRA_CELESTIAL);
            scionsData[_tokenIdTracker.current()].halo = Asset(true, AssetRarity.EXTRA_CELESTIAL);
            scionsData[_tokenIdTracker.current()].head = Asset(true, AssetRarity.EXTRA_CELESTIAL);
            scionsData[_tokenIdTracker.current()].body = Asset(true, AssetRarity.EXTRA_CELESTIAL);
            scionsData[_tokenIdTracker.current()].wings = Asset(true, AssetRarity.EXTRA_CELESTIAL);
            scionsData[_tokenIdTracker.current()].hands = Asset(true, AssetRarity.EXTRA_CELESTIAL);
            scionsData[_tokenIdTracker.current()].sigil = Asset(true, AssetRarity.EXTRA_CELESTIAL);
        }
        
        _safeMint(msg.sender, _tokenIdTracker.current());
        _tokenIdTracker.increment();
    }
    
    // Sets the uri, url of ipfs
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
       _setTokenURI(tokenId, _tokenURI);
    }

    function burnForSoul(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
       _burn(tokenId);

       soul.safeTransfer(msg.sender, 100e18);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "ipfs://";
    }

    function rarity(uint256 tokenId) external view returns (uint256 _rarity) {

        _rarity += uint256(scionsData[tokenId].background.rarity) + 1;
        _rarity += uint256(scionsData[tokenId].halo.rarity) + 1;
        _rarity += uint256(scionsData[tokenId].head.rarity) + 1;
        _rarity += uint256(scionsData[tokenId].body.rarity) + 1;

        _rarity += scionsData[tokenId].wings.hasIt ? uint256(scionsData[tokenId].wings.rarity) + 1 : 0;
        _rarity += scionsData[tokenId].hands.hasIt ? uint256(scionsData[tokenId].hands.rarity) + 1 : 0;
        _rarity += scionsData[tokenId].sigil.hasIt ? uint256(scionsData[tokenId].sigil.rarity) + 1 : 0;
    }


    // Common:
    // ● 5 or less assets;
    // ● 2 or less assets are rare.


    // Rare:
    // ● 5 or less assets;
    // ● 2 or less assets are epicEpic
    
    // Legendary: 6 Legendary Assets
    
    // Extra-celestial: 7 Legendary Assets

    // 75% 20% 4% 1% 0% 0%
    function commonMintPassChances(uint256 _number) private returns (AssetRarity rarity){
        if(_number >= 1 && _number <= 75) return AssetRarity.COMMON;
        if(_number >= 76 && _number <= 95) return AssetRarity.RARE;
        if(_number >= 96 && _number <= 99) return AssetRarity.EPIC_RARE;
        if(_number == 100) return AssetRarity.LEGENDARY;
    }

    // 30% 50% 15% 4% 1% 0%
    function rareMintPassChances(uint256 _number) private returns (AssetRarity rarity){
        if(_number >= 1 && _number <= 30) return AssetRarity.COMMON;
        if(_number >= 31 && _number <= 80) return AssetRarity.RARE;
        if(_number >= 81 && _number <= 95) return AssetRarity.EPIC_RARE;
        if(_number >= 96 && _number <= 99) return AssetRarity.LEGENDARY;
        if(_number == 100) return AssetRarity.MYSTIC;
    }

    // 20% 25% 35% 15% 5% 0%
    function epicRareMintPassChances(uint256 _number) private returns (AssetRarity rarity){
        if(_number >= 1 && _number <= 20) return AssetRarity.COMMON;
        if(_number >= 21 && _number <= 45) return AssetRarity.RARE;
        if(_number >= 46 && _number <= 80) return AssetRarity.EPIC_RARE;
        if(_number >= 81 && _number <= 95) return AssetRarity.LEGENDARY;
        if(_number >= 96 && _number <= 100) return AssetRarity.MYSTIC;
    }

    // 10% 15% 20% 30% 20% 5%
    function legendaryMintPassChances(uint256 _number) private returns (AssetRarity rarity){
        if(_number >= 1 && _number <= 10) return AssetRarity.COMMON;
        if(_number >= 11 && _number <= 25) return AssetRarity.RARE;
        if(_number >= 26 && _number <= 45) return AssetRarity.EPIC_RARE;
        if(_number >= 46 && _number <= 75) return AssetRarity.LEGENDARY;
        if(_number >= 76 && _number <= 95) return AssetRarity.MYSTIC;
        if(_number >= 96 && _number <= 100) return AssetRarity.EXTRA_CELESTIAL;
    }

    // 0% 10% 15% 25% 40% 10%
    function mysticMintPassChances(uint256 _number) private returns (AssetRarity rarity){
        if(_number >= 1 && _number <= 10) return AssetRarity.RARE;
        if(_number >= 11 && _number <= 25) return AssetRarity.EPIC_RARE;
        if(_number >= 26 && _number <= 50) return AssetRarity.LEGENDARY;
        if(_number >= 51 && _number <= 90) return AssetRarity.MYSTIC;
        if(_number >= 91 && _number <= 100) return AssetRarity.EXTRA_CELESTIAL;
    }

    // 100%
    function extraCelestialMintPassChances() private returns (AssetRarity rarity){
        return AssetRarity.EXTRA_CELESTIAL;
    }
}