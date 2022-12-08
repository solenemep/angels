//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./Creature.sol";

contract Archangel is Creature {
    function __Archangel_init(
        string memory _name,
        string memory _symbol,
        string memory _uriBase
    ) external initializer {
        __Creature_init(_name, _symbol, _uriBase);
    }
}
