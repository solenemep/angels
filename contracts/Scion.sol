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

    uint32 callbackGasLimit = 1200000;
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

    /**
        @notice Whether nesting is currently allowed.
        @dev If false then nesting is blocked, but unnesting is always allowed.
     */
    bool public nestingOpen = false;

    string private _baseTokenURI;

    IERC20 public soul;
    IERC20 public keter;

    mapping(uint256 => uint256) private requestIdToTokenId;
    mapping(uint256 => int256) private requestIdToAssetId;
    mapping(uint256 => uint256) private requestIdToMintPassId;
    mapping(uint256 => bool) private requestIdExists;
    mapping(uint256 => int256) private requestIdToMintPassRarity;
    mapping(uint256 => address) private requestIdToUser;

    Asset[] public backgroundAssets;
    Asset[] public haloAssets;
    Asset[] public headAssets;
    Asset[] public bodyAssets;
    Asset[] public wingsAssets;
    Asset[] public handsAssets;
    Asset[] public sigilAssets;

    struct Asset {
        bool hasIt;
        string asset;
        uint256 weight;
        string name;
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
    event ScionClaimed(address indexed _user, uint256 indexed _scionId, uint256 mintPassId, uint256 mintPassRarity, Scions _assets, uint256 _timestamp);
    event Nested(uint256 indexed tokenId);
    event Unnested(uint256 indexed tokenId);
    event RandomGenerated(uint256[] random);

    constructor(uint64 subscriptionId, address vrfCoordinator, address link, bytes32 _keyHash,  address _mintingPass, address _soul, address _keter, string memory name, string memory symbol, string memory baseTokenURI) ERC721(name, symbol) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        keyHash = _keyHash;
        s_subscriptionId = subscriptionId;
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

    function setBackgroundAssets(string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length && _names.length == _assets.length);

        totalBackgroundAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            backgroundAssets.push(Asset(false, _assets[i], _weights[i], _names[i]));
            totalBackgroundAssetsAmount++;
        }

        totalBackgroundAssetsWeight = _weights[_assets.length-1];
    }

    function setHaloAssets(string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length);

        totalHaloAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            haloAssets.push(Asset(false, _assets[i], _weights[i], _names[i]));
            totalHaloAssetsAmount++;
        }

        totalHaloAssetsWeight = _weights[_assets.length-1];
    }

    function setHeadAssets(string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length);
        
        totalHeadAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            headAssets.push(Asset(false, _assets[i], _weights[i], _names[i]));
            totalHeadAssetsAmount++;
        }

        totalHeadAssetsWeight = _weights[_assets.length-1];
    }

    function setBodyAssets(string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length);
        
        totalBodyAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            bodyAssets.push(Asset(false, _assets[i], _weights[i], _names[i]));
            totalBodyAssetsAmount++;
        }

        totalBodyAssetsWeight = _weights[_assets.length-1];
    }

    function setWingsAssets(string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length);

        totalWingsAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            wingsAssets.push(Asset(false, _assets[i], _weights[i], _names[i]));
            totalWingsAssetsAmount++;
        }

        totalWingsAssetsWeight = _weights[_assets.length-1];
    }

    function setHandsAssets(string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length);

        totalHandsAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            handsAssets.push(Asset(false, _assets[i], _weights[i], _names[i]));
            totalHandsAssetsAmount++;
        }

        totalHandsAssetsWeight = _weights[_assets.length-1];
    }

    function setSigilAssets(string[] memory _assets, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length);

        totalSigilAssetsAmount = 0;

        for(uint256 i; i < _assets.length; i++) {
            sigilAssets.push(Asset(false, _assets[i], _weights[i], _names[i]));
            totalSigilAssetsAmount++;
        }

        totalSigilAssetsWeight = _weights[_assets.length-1];
    }

    // Assumes the subscription is funded sufficiently.
    function requestRandomWords(uint256 scionTokenId, int256 assetId, uint256 mintPassId, int256 mintPassRarity, uint256 numWords) internal returns (uint256 s_requestId) {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            uint32(numWords)
        );

        requestIdToAssetId[s_requestId] = assetId;
        requestIdToMintPassId[s_requestId] = mintPassId;
        requestIdToMintPassRarity[s_requestId] = mintPassRarity;
        requestIdToUser[s_requestId] = msg.sender;
        requestIdToTokenId[s_requestId] = scionTokenId;
        requestIdExists[s_requestId] = true;
    }
    
    function fulfillRandomWords(
        uint256 requestId, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        // Mint when I get the callback 
        if(requestIdExists[requestId]) {              
                emit RandomGenerated(randomWords);

                uint256 previousWeightTemp;
                uint256 tokenId = requestIdToTokenId[requestId];
                int256 _rarity = requestIdToMintPassRarity[requestId];

                uint256 randomNumber = randomWords[0] % totalBackgroundAssetsWeight;
                
                for(uint i; i < backgroundAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= backgroundAssets[i].weight) {
                        scionsData[tokenId].background = Asset(true, backgroundAssets[i].asset, backgroundAssets[i].weight, backgroundAssets[i].name);
                        break;
                    }

                    previousWeightTemp = backgroundAssets[i].weight;
                }

                randomNumber = randomWords[1] % totalHaloAssetsWeight;
                previousWeightTemp = 0;

                for(uint i; i < haloAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= haloAssets[i].weight) {
                        scionsData[tokenId].halo = Asset(true, haloAssets[i].asset, haloAssets[i].weight, haloAssets[i].name);
                        break;
                    }

                    previousWeightTemp = haloAssets[i].weight;
                }

                randomNumber = randomWords[2] % totalHeadAssetsWeight;
                previousWeightTemp = 0;

                for(uint i; i < headAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= headAssets[i].weight) {
                        scionsData[tokenId].head = Asset(true, headAssets[i].asset, headAssets[i].weight, headAssets[i].name);
                        break;
                    }

                    previousWeightTemp = headAssets[i].weight;
                }

                randomNumber = randomWords[3] % totalBodyAssetsWeight;
                previousWeightTemp = 0;

                for(uint i; i < bodyAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= bodyAssets[i].weight) {
                        scionsData[tokenId].body = Asset(true, bodyAssets[i].asset, bodyAssets[i].weight, bodyAssets[i].name);
                        break;
                    }

                    previousWeightTemp = bodyAssets[i].weight;
                }

                randomNumber = randomWords[4] % totalWingsAssetsWeight;
                previousWeightTemp = 0;

                for(uint i; i < wingsAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= wingsAssets[i].weight) {
                        scionsData[tokenId].wings = Asset(true, wingsAssets[i].asset, wingsAssets[i].weight, wingsAssets[i].name);
                        break;
                    }

                    previousWeightTemp = wingsAssets[i].weight;
                }

                randomNumber = randomWords[5] % totalHandsAssetsWeight;
                previousWeightTemp = 0;

                for(uint i; i < handsAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= handsAssets[i].weight) {
                        scionsData[tokenId].hands = Asset(true, handsAssets[i].asset, handsAssets[i].weight, handsAssets[i].name);
                        break;
                    }

                    previousWeightTemp = handsAssets[i].weight;
                }

                randomNumber = randomWords[6] % totalSigilAssetsWeight;
                previousWeightTemp = 0;

                for(uint i; i < sigilAssets.length; i++) {
                    if(randomNumber > previousWeightTemp && randomNumber <= sigilAssets[i].weight) {
                        scionsData[tokenId].sigil = Asset(true, sigilAssets[i].asset, sigilAssets[i].weight, sigilAssets[i].name);
                        break;
                    }

                    previousWeightTemp = sigilAssets[i].weight;
                }

                requestIdExists[requestId] = false;

                emit ScionClaimed(requestIdToUser[requestId], tokenId, requestIdToMintPassId[requestId], uint256(_rarity), scionsData[tokenId], block.timestamp);
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
        requestRandomWords(tokenId, int256(assetId), 0, -1, 2);
    }

    function claimScion(uint256 tokenId) public {
        require(mintingPass.ownerOf(tokenId) == msg.sender, "Scion: invalid owner");

        // Burning minting pass
        mintingPass.burn(tokenId);
        
        requestRandomWords(_tokenIdTracker.current(), -1, tokenId, 0, 7);
        
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