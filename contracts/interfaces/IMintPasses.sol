// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IMintPasses is IERC721Upgradeable {
    enum Class {
        NONE,
        BRONZE,
        SILVER,
        GOLD,
        PLATINUM,
        RUBY,
        ONYX
    }

    struct ClassLimits {
        uint256 bottomBidValue;
        uint256 topBidValue;
        uint256 timestamp;
        uint256 bottomAssetWeight;
        uint256 topAssetWeight;
    }

    struct BidInfo {
        uint256 bidIndex;
        address bidder;
        uint256 bidValue;
        uint256 timestamp;
        Class class;
        bool claimed;
    }

    struct MintPassInfo {
        Class class;
        uint256 random;
    }

    enum ListOption {
        ALL,
        OWNED
    }

    function classLimits(Class class)
        external
        returns (
            uint256 bottomBidValue,
            uint256 topBidValue,
            uint256 timestamp,
            uint256 bottomAssetWeight,
            uint256 topAssetWeight
        );

    function mintPassInfos(uint256 mintPassIndex) external returns (Class class, uint256 random);

    function burn(uint256 tokenId) external;
}
