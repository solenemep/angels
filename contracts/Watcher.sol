//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "./Creature.sol";

contract Watcher is Creature {
    function __Watcher_init(
        string memory _name,
        string memory _symbol,
        string memory _uriBase
    ) external initializer {
        __Creature_init(_name, _symbol, _uriBase);
    }
}
