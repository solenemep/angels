// SPDX-License-Identifier: MIT
// An example of a consumer contract that relies on a subscription for funding.
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintPassRarityGenerator is VRFConsumerBaseV2, Ownable {
  VRFCoordinatorV2Interface COORDINATOR;
  LinkTokenInterface LINKTOKEN;

  // Your subscription ID.
  uint64 s_subscriptionId;

  bytes32 keyHash;

  uint32 callbackGasLimit = 100000;

  // The default is 3, but you can set this higher.
  uint16 requestConfirmations = 3;

  // For this example, retrieve 2 random values in one request.
  // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
  uint32 numWords =  1;

  enum Rarity {
    COMMON,
    RARE,
    EPIC,
    EPIC_RARE,
    LEGENDARY,
    MYSTIC, 
    EXTRA_CELESTIAL
  }

  // Top and bottom limits of rarities
  uint256[2] public commonLimits;
  uint256[2] public rareLimits;
  uint256[2] public epicLimits;
  uint256[2] public epicRareLimits;
  uint256[2] public legendaryLimits;
  uint256[2] public mysticLimits;

  mapping (uint256 => Rarity) public mintingPassRarity;
  mapping(uint256 => uint256) private requestIdToTokenId;

  constructor(uint64 subscriptionId, address vrfCoordinator, address link, bytes32 _keyHash) 
    VRFConsumerBaseV2(vrfCoordinator) {
    COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    LINKTOKEN = LinkTokenInterface(link);
    keyHash = _keyHash;
    s_subscriptionId = subscriptionId;

    commonLimits = [1, 100];
    rareLimits = [101, 150];
    epicLimits = [151, 170];
    epicRareLimits = [171, 186];
    legendaryLimits = [187,196];
    mysticLimits = [197,200];
  }

  // Assumes the subscription is funded sufficiently.
  function requestRandomWords(uint256 tokenId) public onlyOwner returns (uint256 s_requestId) {
    // Will revert if subscription is not set and funded.
    s_requestId = COORDINATOR.requestRandomWords(
      keyHash,
      s_subscriptionId,
      requestConfirmations,
      callbackGasLimit,
      numWords
    );
    requestIdToTokenId[s_requestId] = tokenId;
  }
  
  function fulfillRandomWords(
    uint256 requestId, /* requestId */
    uint256[] memory randomWords
  ) internal override {
    // Mint when I get the callback 
    if(requestIdToTokenId[requestId] > 0){
      uint256 randomNumber = (randomWords[0] % 200) + 1;
      Rarity _rarity = _calculateRarityForPromotion(randomNumber);
      mintingPassRarity[requestIdToTokenId[requestId]] = _rarity;
    }
  }

  function setPromotionLimits(
    uint256[2] memory _commonLimits,
    uint256[2] memory _rareLimits,
    uint256[2] memory _epicLimits,
    uint256[2] memory _epicRareLimits,
    uint256[2] memory _legendaryLimits,
    uint256[2] memory _mysticLimits
  ) public onlyOwner {
    _setPromotionLimit(commonLimits, _commonLimits);
    _setPromotionLimit(rareLimits, _rareLimits);
    _setPromotionLimit(epicLimits, _epicLimits);
    _setPromotionLimit(epicRareLimits, _epicRareLimits);
    _setPromotionLimit(legendaryLimits, _legendaryLimits);
    _setPromotionLimit(mysticLimits, _mysticLimits);
  }

  function _calculateRarityForPromotion(uint256 _number) private view returns (Rarity rarity){
    if(_number >= commonLimits[0] && _number <= commonLimits[1]) return Rarity.COMMON;
    if(_number >= rareLimits[0] && _number <= rareLimits[1]) return Rarity.RARE;
    if(_number >= epicLimits[0] && _number <= epicLimits[1]) return Rarity.EPIC;
    if(_number >= epicRareLimits[0] && _number <= epicRareLimits[1]) return Rarity.EPIC_RARE;
    if(_number >= legendaryLimits[0] && _number <= legendaryLimits[1]) return Rarity.LEGENDARY;
    if(_number >= mysticLimits[0] && _number <= mysticLimits[1]) return Rarity.MYSTIC;
  }

  function _setPromotionLimit(
    uint256[2] storage limitToSet, 
    uint256[2] memory limitValues
    ) private {
    for(uint256 i=0; i < limitValues.length; i++){
      require(limitValues[i] > 0, 'MintPassRarity: invalid limit value');
      limitToSet[i] = limitValues[i];
    }
  }

  // Shows the minting pass rarity
  function getMintingPassData(uint256 tokenId) public view returns (Rarity){
    return mintingPassRarity[tokenId];
  }
}