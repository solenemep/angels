//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface IAssetRegistry {
    struct Asset {
        bool hasIt;
        string asset;
        uint256 weightSum;
        uint256 weight;
        string name;
        uint256 assetIndex;
    }

    function uniqueWeightsForType(uint256 _assetId) external view returns (uint256[] memory);

    function uniqueWeightsForTypeIndexes(uint256 _assetId, uint256 _weights)
        external
        view
        returns (uint256);

    function assetsForType(uint256 _assetId) external view returns (Asset[] memory);

    function totalWeightForType(uint256 _assetId) external view returns (uint256);
}
