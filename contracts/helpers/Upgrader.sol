// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Upgrader is Ownable {
    constructor() {}

    function upgrade(address what, address to) external onlyOwner {
        TransparentUpgradeableProxy(payable(what)).upgradeTo(to);
    }

    function upgradeAndCall(
        address what,
        address to,
        bytes calldata data
    ) external onlyOwner {
        TransparentUpgradeableProxy(payable(what)).upgradeToAndCall(to, data);
    }

    function getImplementation(address what) external onlyOwner returns (address) {
        return TransparentUpgradeableProxy(payable(what)).implementation();
    }
}
