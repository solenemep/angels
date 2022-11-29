//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Creature.sol";

contract Watcher is Initializable, Creature {
    function __Watcher_init(
        string memory _name,
        string memory _symbol,
        string memory _uriBase
    ) external initializer {
        __Creature_init(_name, _symbol, _uriBase);
    }
}
