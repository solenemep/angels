//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Creature.sol";

contract Archangel is Initializable, Creature {
    function __Archangel_init(string memory _uriBase, address registryAddress)
        external
        initializer
    {
        __Creature_init("Archangel", "ARCH", _uriBase, registryAddress);
    }
}
