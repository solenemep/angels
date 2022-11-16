//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

abstract contract Angel is Ownable, ReentrancyGuard {
    function setPriceInSouls(uint256 _priceInSouls) external virtual onlyOwner {}

    function angelsLeft() external view virtual returns (uint256) {}

    function getBatchIndex() external view virtual returns (uint256) {}

    function triggerBatchSale(uint256 _priceInSouls) external virtual onlyOwner {}

    function claimAngel() external virtual nonReentrant {}
}
