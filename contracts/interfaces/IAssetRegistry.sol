//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface IAssetRegistry {
    struct AssetInfo {
        string asset;
        uint256 weight;
        string name;
        uint256 assetIndex; // to be deleted ?
    }

    function getAssetInfo(uint256 _assetId, uint256 _assetIndex)
        external
        view
        returns (AssetInfo memory assetPerTypePerIndex);

    function getAssetsPerType(uint256 _assetId)
        external
        view
        returns (AssetInfo[] memory assetIndexesPerType);

    function getAssetsPerTypePerWeight(uint256 _assetId, uint256 _weight)
        external
        view
        returns (AssetInfo[] memory assetIndexesPerTypePerWeight);

    function getAssetsPerTypePerWeightRange(
        uint256 _assetId,
        uint256 _minWeight,
        uint256 _maxWeight
    ) external view returns (AssetInfo[] memory assetIndexesPerTypePerWeightRange);

    function getTotalWeightArray(AssetInfo[] memory assetArray)
        external
        pure
        returns (uint256 totalWeightArray);

    function uniqueWeightsForType(uint256 _assetId) external view returns (uint256[] memory);

    function uniqueWeightsForTypeIndexes(uint256 _assetId, uint256 _weights)
        external
        view
        returns (uint256);
}
