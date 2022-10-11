//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IAssetRegistry.sol";

contract AssetsRegistry is Ownable, IAssetRegistry {
    // asset type -> set of weights
    mapping(uint256 => uint256[]) public assetsUniqueWeights;

    mapping(uint256 => mapping(uint256 => uint256))
        public assetsUniqueWeightsIndexes;

    // asset type -> array of assets
    mapping(uint256 => Asset[]) public assets;

    constructor() {}

    function setAssets(
        uint256 _assetId,
        string[] memory _assets,
        uint256[] memory _weightSum,
        uint256[] memory _weights,
        string[] memory _names
    ) external onlyOwner {
        require(
            _assets.length == _weights.length &&
                _names.length == _assets.length &&
                _weightSum.length == _assets.length
        );
        assetsTotalAmount[_assetId] = 0;
        uint256 _previousWeight;
        for (uint256 i; i < _assets.length; i++) {
            assets[_assetId].push(
                Asset(false, _assets[i], _weightSum[i], _weights[i], _names[i], i)
            );
            assetsTotalAmount[_assetId]++;

            if (_weights[i] != _previousWeight) {
                _previousWeight = _weights[i];
                assetsUniqueWeightsIndexes[_assetId][_weights[i]] = assetsUniqueWeights[_assetId]
                    .length;
                assetsUniqueWeights[_assetId].push(_weights[i]);
            }
        }
        assetsTotalWeight[_assetId] = _weightSum[_assets.length - 1];
    }

    function setAssets(uint _assetId, string[] memory _assets, uint256[] memory _weightSum, uint256[] memory _weights, string[] memory _names) external onlyOwner {
        require(_assets.length == _weights.length && _names.length == _assets.length && _weightSum.length == _assets.length);
        assetsTotalAmount[_assetId] = 0;
        uint _previousWeight;
        for(uint256 i; i < _assets.length; i++) {
            assets[_assetId].push(Asset(false, _assets[i], _weightSum[i], _weights[i], _names[i], i));
            assetsTotalAmount[_assetId]++;

            if(_weights[i] != _previousWeight) {
                _previousWeight = _weights[i];
                assetsUniqueWeightsIndexes[_assetId][_weights[i]] = assetsUniqueWeights[_assetId].length;
                assetsUniqueWeights[_assetId].push(_weights[i]);
            }
        }
        assetsTotalWeight[_assetId] = _weightSum[_assets.length - 1];
    }

    function uniqueWeightsForTypeIndexes(uint256256 _assetId, uint256256 _weights)
       
        public
       
        view
       
        override
       
        returns (uint256)
   
    {
        return assetsUniqueWeightsIndexes[_assetId][_weights];
    }

    function uniqueWeightsForType(uint256 _assetId)
        public
        view
        override
        returns (uint256[] memory)
    {
        return assetsUniqueWeights[_assetId];
    }

    function assetsForType(uint256 _assetId) public view override returns (Asset[] memory) {
        return assets[_assetId];
    }

    function totalWeightForType(uint256 _assetId) public view override returns (uint256) {
        return assetsTotalWeight[_assetId];
    }
}
