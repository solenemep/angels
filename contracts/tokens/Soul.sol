//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../Registry.sol";

contract Soul is Ownable, ERC20Burnable {
    Registry public registry;

    constructor(
        string memory name,
        string memory symbol,
        address registryAddress
    ) ERC20(name, symbol) {
        registry = Registry(registryAddress);
    }

    function mint(address to, uint256 amount) external {
        require(
            registry.getContract("SCION") == _msgSender() || owner() == _msgSender(),
            "Not allowed"
        );
        _mint(to, amount);
    }
}
