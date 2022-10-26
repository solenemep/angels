//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./MintPasses.sol";

// We import this library to be able to use console.log
import "hardhat/console.sol";

// This is the main building block for smart contracts.
contract MintPassesHolder is Context, Ownable, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.AddressSet;

    MintPasses public mintPasses;

    // promotion related
    EnumerableSet.AddressSet internal _promotionBeneficiaries;
    mapping(MintPasses.Class => uint256) public promotionPrices; // class -> price

    event PromotionPassClaimed(
        address indexed beneficiary,
        uint256 indexed passId,
        uint256 timestamp
    );

    constructor(address _mintPassesAddress) {
        mintPasses = MintPasses(_mintPassesAddress);
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

        payable(mintPasses.treasury()).transfer(msg.value);

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
