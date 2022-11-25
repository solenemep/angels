//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./interfaces/IAssetRegistry.sol";

contract AssetsRegistry is OwnableUpgradeable, IAssetRegistry {
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 private _latestAssetId;

    // asset related
    mapping(uint256 => mapping(uint256 => AssetInfo)) public assetInfos; // asset type -> asset index -> asset info
    mapping(uint256 => EnumerableSet.UintSet) internal _allAssets; // asset type -> asset indexes
    mapping(uint256 => mapping(uint256 => EnumerableSet.UintSet)) internal _assetsPerWeight; // asset type -> weight -> asset indexes

    // asset type -> set of weights
    mapping(uint256 => uint256[]) public assetsUniqueWeights;

    function __AssetRegistry_init() external initializer {
        __Ownable_init();
        _latestAssetId = 1;
    }

    function setAssets(
        uint256 _assetId,
        string[] memory _assets,
        uint256[] memory _weights,
        string[] memory _names
    ) external onlyOwner {
        require(_assets.length == _weights.length && _weights.length == _names.length);

        uint256 _previousWeight;

        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 newAssetIndex = _latestAssetId;

            assetInfos[_assetId][newAssetIndex].asset = _assets[i];
            assetInfos[_assetId][newAssetIndex].weight = _weights[i];
            assetInfos[_assetId][newAssetIndex].name = _names[i];
            assetInfos[_assetId][newAssetIndex].assetIndex = newAssetIndex;

            _allAssets[_assetId].add(newAssetIndex);
            _assetsPerWeight[_assetId][_weights[i]].add(newAssetIndex);

            if (_weights[i] != _previousWeight) {
                _previousWeight = _weights[i];
                assetsUniqueWeights[_assetId].push(_weights[i]);
            }

            _latestAssetId++;
        }
    }

    function getAssetInfo(uint256 _assetId, uint256 _assetIndex)
        public
        view
        override
        returns (AssetInfo memory assetPerTypePerIndex)
    {
        assetPerTypePerIndex = assetInfos[_assetId][_assetIndex];
    }

    function getAssetsPerType(uint256 _assetId)
        public
        view
        override
        returns (AssetInfo[] memory assetsPerType)
    {
        uint256 count = _allAssets[_assetId].length();
        assetsPerType = new AssetInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            uint256 assetIndex = _allAssets[_assetId].at(i);
            assetsPerType[i] = assetInfos[_assetId][assetIndex];
        }
    }

    function getAssetsPerTypePerWeight(uint256 _assetId, uint256 _weight)
        public
        view
        override
        returns (AssetInfo[] memory assetsPerTypePerWeight)
    {
        uint256 count = _assetsPerWeight[_assetId][_weight].length();
        assetsPerTypePerWeight = new AssetInfo[](count);
        for (uint256 i = 0; i < count; i++) {
            uint256 assetIndex = _assetsPerWeight[_assetId][_weight].at(i);
            assetsPerTypePerWeight[i] = assetInfos[_assetId][assetIndex];
        }
    }

    function getAssetsPerTypePerWeightRange(
        uint256 _assetId,
        uint256 _minWeight,
        uint256 _maxWeight
    ) public view override returns (AssetInfo[] memory assetsPerTypePerWeightRange) {
        uint256[] memory weightsPerType = assetsUniqueWeights[_assetId];

        uint256 count;
        for (uint256 i = 0; i < weightsPerType.length; i++) {
            if (_minWeight <= weightsPerType[i] && weightsPerType[i] <= _maxWeight) {
                count += _assetsPerWeight[_assetId][weightsPerType[i]].length();
            }
        }

        assetsPerTypePerWeightRange = new AssetInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < weightsPerType.length; i++) {
            if (_minWeight <= weightsPerType[i] && weightsPerType[i] <= _maxWeight) {
                for (
                    uint256 j = 0;
                    j < _assetsPerWeight[_assetId][weightsPerType[i]].length();
                    j++
                ) {
                    uint256 assetIndex = _assetsPerWeight[_assetId][weightsPerType[i]].at(j);
                    assetsPerTypePerWeightRange[index] = assetInfos[_assetId][assetIndex];
                    index++;
                }
            }
        }
    }

    function getTotalWeightArray(AssetInfo[] memory assetArray)
        public
        pure
        override
        returns (uint256 totalWeightArray)
    {
        for (uint256 i = 0; i < assetArray.length; i++) {
            totalWeightArray += assetArray[i].weight;
        }
    }

    function uniqueWeightsForType(uint256 _assetId)
        public
        view
        override
        returns (uint256[] memory)
    {
        return assetsUniqueWeights[_assetId];
    }
}
