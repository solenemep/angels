//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./MintPasses.sol";

// This is the main building block for smart contracts.
contract MintPassesHolder is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    Registry public registry;
    MintPasses public mintPasses;

    // promotion related
    EnumerableSet.AddressSet internal _promotionBeneficiaries;
    mapping(MintPasses.Class => uint256) public promotionPrices; // class -> price

    event PromotionPassClaimed(
        address indexed beneficiary,
        uint256 indexed passId,
        uint256 timestamp
    );

    function __MintPassesHolder_init(address registryAddress) external initializer {
        registry = Registry(registryAddress);

        __Ownable_init();
        __ReentrancyGuard_init();
    }

    function setDependencies() external onlyOwner {
        mintPasses = MintPasses(registry.getContract("MINTPASS"));
    }

    function addPromotionMintingAddress(address _beneficiary) public onlyOwner nonReentrant {
        require(!_promotionBeneficiaries.contains(_beneficiary), "MintPasses: Already added");
        _promotionBeneficiaries.add(_beneficiary);
    }

    function setPricePerClassPromotion(MintPasses.Class[] memory classes, uint256[] memory prices)
        public
        onlyOwner
    {
        require(classes.length == prices.length, "Data mismatch");
        for (uint256 i = 0; i < classes.length; i++) {
            promotionPrices[classes[i]] = prices[i];
        }
    }

    function buyPromotionMintPass(uint256 _tokenId) external payable nonReentrant {
        (MintPasses.Class class, ) = mintPasses.mintPassInfos(_tokenId);
        require(promotionPrices[class] > 0, "Prices not set yet");
        require(_promotionBeneficiaries.contains(_msgSender()), "Not beneficiary");

        require(msg.value == promotionPrices[class], "There is not enough funds to buy");
        _promotionBeneficiaries.remove(_msgSender());

        payable(registry.getContract("TREASURY")).transfer(msg.value);

        mintPasses.transferFrom(address(this), _msgSender(), _tokenId);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
