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

    function uniqueWeightsForType(uint _assetId) external view returns (uint256[] memory);
    
    function uniqueWeightsForTypeIndexes(uint _assetId, uint _weights) external view returns (uint256);

    function assetsForType(uint _assetId) external view returns (Asset[] memory);

    function totalWeightForType(uint _assetId) external view returns (uint256);
}
