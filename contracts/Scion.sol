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

    /**
        @dev tokenId to nesting start time (0 = not nesting).
     */
    mapping(uint256 => uint256) private nestingStarted;

    /**
        @dev Cumulative per-token nesting, excluding the current period.
     */
    mapping(uint256 => uint256) private nestingTotal;

    // Your subscription ID.
    uint64 s_subscriptionId;

    bytes32 keyHash;

    uint32 callbackGasLimit = 500000;
    uint256 rerollPrice = 1e18;
    uint256 priceForRarityInSouls = 100e18;

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

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    IERC20 public soul;
    IERC20 public keter;

    mapping(uint256 => uint256) private requestIdToTokenId;
    mapping(uint256 => int256) private requestIdToAssetId;
    mapping(uint256 => bool) private requestIdExists;
    mapping(uint256 => int256) private requestIdToMintPassRarity;
    mapping (bytes32 => uint256) public assetIndexes;

    Asset[] public backgroundAssets;
    Asset[] public haloAssets;
    Asset[] public headAssets;
    Asset[] public bodyAssets;
    Asset[] public wingsAssets;
    Asset[] public handsAssets;
    Asset[] public sigilAssets;

    struct Asset {
        bool hasIt;
        bytes32 asset;
        uint256 weight;
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

    event Reroll(uint256 indexed _tokenId, uint256 indexed _assetId, int256 _previousRarity, int256 _newRarity, uint256 _timestamp);
    event AssetGenerated(uint256 indexed _tokenId, uint256 indexed _assetId, int256 _rarity, uint256 _timestamp);
    event ScionClaimed(address indexed _user, uint256 indexed _scionId, uint256 indexed _mintPassId, uint256 mintPassRarity, uint256 _timestamp);
    event Nested(uint256 indexed tokenId);
    event Unnested(uint256 indexed tokenId);

    constructor(uint64 subscriptionId, address vrfCoordinator, address link, bytes32 _keyHash, address _mintingPass, address _soul, address _keter, string memory name, string memory symbol) ERC721(name, symbol) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        keyHash = _keyHash;
        s_subscriptionId = subscriptionId;
        mintingPass = MintPasses(_mintingPass);
        soul = IERC20(_soul);
        keter = IERC20(_keter);
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

    function setPriceInSoulsForRarity(uint256 _priceInSouls) external onlyOwner {
        priceForRarityInSouls = _priceInSouls;
    }

    function setBackgroundAssets(bytes32[] memory _assets, uint256[] memory _weights) external onlyOwner {
        require(_assets.length == _weights.length);

        totalBackgroundAssetsWeight = 0;
        totalBackgroundAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            assetIndexes[_assets[i]] = totalBackgroundAssetsAmount;
            backgroundAssets.push(Asset(false, _assets[i], _weights[i]));
            totalBackgroundAssetsWeight += _weights[i];
            totalBackgroundAssetsAmount++;
        }
    }

    function setHaloAssets(bytes32[] memory _assets, uint256[] memory _weights) external onlyOwner {
        require(_assets.length == _weights.length);

        totalHaloAssetsWeight = 0;
        totalHaloAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            assetIndexes[_assets[i]] = totalHaloAssetsAmount;
            haloAssets.push(Asset(false, _assets[i], _weights[i]));
            totalHaloAssetsWeight += _weights[i];
            totalHaloAssetsAmount++;
        }
    }

    function setHeadAssets(bytes32[] memory _assets, uint256[] memory _weights) external onlyOwner {
        require(_assets.length == _weights.length);
        
        totalHeadAssetsWeight = 0;
        totalHeadAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            assetIndexes[_assets[i]] = totalHeadAssetsAmount;
            headAssets.push(Asset(false, _assets[i], _weights[i]));
            totalHeadAssetsWeight += _weights[i];
            totalHeadAssetsAmount++;
        }
    }

    function setBodyAssets(bytes32[] memory _assets, uint256[] memory _weights) external onlyOwner {
        require(_assets.length == _weights.length);
        
        totalBodyAssetsWeight = 0;
        totalBodyAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            assetIndexes[_assets[i]] = totalBodyAssetsAmount;
            bodyAssets.push(Asset(false, _assets[i], _weights[i]));
            totalBodyAssetsWeight += _weights[i];
            totalBodyAssetsAmount++;
        }
    }

    function setWingsAssets(bytes32[] memory _assets, uint256[] memory _weights) external onlyOwner {
        require(_assets.length == _weights.length);

        totalWingsAssetsWeight = 0;
        totalWingsAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            assetIndexes[_assets[i]] = totalWingsAssetsAmount;
            wingsAssets.push(Asset(false, _assets[i], _weights[i]));
            totalWingsAssetsWeight += _weights[i];
            totalWingsAssetsAmount++;
        }
    }

    function setHandsAssets(bytes32[] memory _assets, uint256[] memory _weights) external onlyOwner {
        require(_assets.length == _weights.length);

        totalHandsAssetsAmount = 0;
        totalHandsAssetsWeight = 0;

        for(uint256 i; i < _assets.length; i++) {
            assetIndexes[_assets[i]] = totalHandsAssetsAmount;
            handsAssets.push(Asset(false, _assets[i], _weights[i]));
            totalHandsAssetsWeight += _weights[i];
            totalHandsAssetsAmount++;
        }
    }

    function setSigilAssets(bytes32[] memory _assets, uint256[] memory _weights) external onlyOwner {
        require(_assets.length == _weights.length);

        totalSigilAssetsAmount = 0;
        totalSigilAssetsWeight = 0;

        for(uint256 i; i < _assets.length; i++) {
            assetIndexes[_assets[i]] = totalSigilAssetsAmount;
            sigilAssets.push(Asset(false, _assets[i], _weights[i]));

            totalSigilAssetsWeight += _weights[i];
            totalSigilAssetsAmount++;
        }
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
                
                uint256 assetsAmount = randomWords.length;
                uint256 nonCommonAmount;
                uint256 previousWeightTemp;

                uint256 randomNumber = randomWords[0] % totalBackgroundAssetsWeight;
                
                for(uint i = 1; i < backgroundAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= backgroundAssets[i].weight) {
                        scionsData[requestIdToTokenId[requestId]].background = Asset(true, backgroundAssets[i].asset, backgroundAssets[i].weight);
                        break;
                    }

                    previousWeightTemp = backgroundAssets[i].weight;
                }

                randomNumber = randomWords[1] % totalHaloAssetsWeight;
                previousWeightTemp = 0;

                for(uint i = 1; i < haloAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= haloAssets[i].weight) {
                        scionsData[requestIdToTokenId[requestId]].halo = Asset(true, haloAssets[i].asset, haloAssets[i].weight);
                        break;
                    }

                    previousWeightTemp = haloAssets[i].weight;
                }

                randomNumber = randomWords[2] % totalHaloAssetsWeight;

                for(uint i = 1; i < headAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= headAssets[i].weight) {
                        scionsData[requestIdToTokenId[requestId]].head = Asset(true, headAssets[i].asset, headAssets[i].weight);
                        break;
                    }

                    previousWeightTemp = headAssets[i].weight;
                }

                randomNumber = randomWords[3] % totalBodyAssetsWeight;

                for(uint i = 1; i < bodyAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= headAssets[i].weight) {
                        scionsData[requestIdToTokenId[requestId]].body = Asset(true, bodyAssets[i].asset, bodyAssets[i].weight);
                        break;
                    }

                    previousWeightTemp = bodyAssets[i].weight;
                }

                randomNumber = randomWords[4] % totalWingsAssetsWeight;

                for(uint i = 1; i < wingsAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= headAssets[i].weight) {
                        scionsData[requestIdToTokenId[requestId]].wings = Asset(true, wingsAssets[i].asset, wingsAssets[i].weight);
                        break;
                    }

                    previousWeightTemp = headAssets[i].weight;
                }

                randomNumber = randomWords[5] % totalHandsAssetsWeight;

                for(uint i = 1; i < handsAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= handsAssets[i].weight) {
                        scionsData[requestIdToTokenId[requestId]].hands = Asset(true, handsAssets[i].asset, handsAssets[i].weight);
                        break;
                    }

                    previousWeightTemp = handsAssets[i].weight;
                }

                randomNumber = randomWords[6] % totalSigilAssetsWeight;

                for(uint i = 1; i < sigilAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= sigilAssets[i].weight) {
                        scionsData[requestIdToTokenId[requestId]].sigil = Asset(true, sigilAssets[i].asset, sigilAssets[i].weight);
                        break;
                    }

                    previousWeightTemp = sigilAssets[i].weight;
                }

            requestIdExists[requestId] = false;
            }
        }
    }

    // // rarity should not be less then it was before
    // function rerollCalculate(uint256 randomNumber, uint256 assetId, uint256 tokenId, int256 _previousRarity) private {
    //     if(randomNumber < 70) {
    //         if(assetId == 4) {
    //             scionsData[tokenId].wings = Asset(true, _previousRarity > int256(uint256(AssetRarity.RARE)) ? AssetRarity(_previousRarity) : AssetRarity.RARE);
    //         }

    //         if(assetId == 5) {
    //             scionsData[tokenId].hands = Asset(true, _previousRarity > int256(uint256(AssetRarity.RARE)) ? AssetRarity(_previousRarity) : AssetRarity.RARE);
    //         }

    //         if(assetId == 6) {
    //             scionsData[tokenId].sigil = Asset(true, _previousRarity > int256(uint256(AssetRarity.RARE)) ? AssetRarity(_previousRarity) : AssetRarity.RARE);
    //         }
            
    //         emit Reroll(tokenId, assetId, _previousRarity, int256(uint256(AssetRarity.RARE)), block.timestamp);
    //     } else if(randomNumber >= 70 && randomNumber <= 95) {
    //         if(assetId == 4) {
    //             scionsData[tokenId].wings = Asset(true, _previousRarity > int256(uint256(AssetRarity.EPIC_RARE)) ? AssetRarity(_previousRarity) : AssetRarity.EPIC_RARE);
    //         }

    //         if(assetId == 5) {
    //             scionsData[tokenId].hands = Asset(true, _previousRarity > int256(uint256(AssetRarity.EPIC_RARE)) ? AssetRarity(_previousRarity) : AssetRarity.EPIC_RARE);
    //         }

    //         if(assetId == 6) {
    //             scionsData[tokenId].sigil = Asset(true, _previousRarity > int256(uint256(AssetRarity.EPIC_RARE)) ? AssetRarity(_previousRarity) : AssetRarity.EPIC_RARE);
    //         }

    //         emit Reroll(tokenId, assetId, _previousRarity, int256(uint256(AssetRarity.EPIC_RARE)), block.timestamp);
    //     } else {
    //         if(assetId == 4) {
    //             scionsData[tokenId].wings = Asset(true, _previousRarity > int256(uint256(AssetRarity.LEGENDARY)) ? AssetRarity(_previousRarity) : AssetRarity.LEGENDARY);
    //         }

    //         if(assetId == 5) {
    //             scionsData[tokenId].hands = Asset(true, _previousRarity > int256(uint256(AssetRarity.LEGENDARY)) ? AssetRarity(_previousRarity) : AssetRarity.LEGENDARY);
    //         }

    //         if(assetId == 6) {
    //             scionsData[tokenId].sigil = Asset(true, _previousRarity > int256(uint256(AssetRarity.LEGENDARY)) ? AssetRarity(_previousRarity) : AssetRarity.LEGENDARY);
    //         }

    //         emit Reroll(tokenId, assetId, _previousRarity, int256(uint256(AssetRarity.LEGENDARY)), block.timestamp);
    //     }
    // }

    // Shows the minting pass rarity
    // function getMintingPassData(uint256 tokenId) public view returns (Rarity){
    //     return mintingPassRarity[tokenId];
    // }

    function rerollAsset(uint256 tokenId, uint256 assetId) public {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        require(assetId <= 6);

        keter.safeTransferFrom(msg.sender, address(this), rerollPrice);
        requestRandomWords(tokenId, int256(assetId), -1, 2);
    }

    function claimScion(uint256 tokenId) public {
        require(mintingPass.ownerOf(tokenId) == msg.sender, "Scion: invalid owner");
        
        int256 rarity = int256(uint256(mintingPass.getMintingPassData(tokenId)));

        // Burning minting pass
        mintingPass.burn(tokenId);
        
        requestRandomWords(_tokenIdTracker.current(), -1, 0, 6);
        
        _safeMint(msg.sender, _tokenIdTracker.current());
        emit ScionClaimed(msg.sender, _tokenIdTracker.current(), tokenId, uint256(rarity), block.timestamp);

        _tokenIdTracker.increment();
    }
    
    // Sets the uri, url of ipfs
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external {
       _setTokenURI(tokenId, _tokenURI);
    }

    function burnForSoul(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Scion: invalid owner");

        soul.safeTransfer(msg.sender, rarity(tokenId) * priceForRarityInSouls);
       _burn(tokenId); // add new burn with scionsData
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "";
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