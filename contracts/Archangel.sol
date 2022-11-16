//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./Creature.sol";

contract Archangel is Creature {
    constructor(
        address _soul,
        uint256 _priceInSouls,
        string memory _uriBase
    ) Creature("Archangel", "ARCH", _soul, _priceInSouls, _uriBase) {}
}
