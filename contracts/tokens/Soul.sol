//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../Registry.sol";
import "../Scion.sol";

import "../interfaces/tokens/ISoul.sol";

contract Soul is ISoul, Ownable, ERC20Burnable {
    Scion public scion;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function setDependencies(address registryAddress) external onlyOwner {
        scion = Scion(Registry(registryAddress).getContract("SCION"));
    }

    function mint(address to, uint256 amount) external override {
        require(address(scion) == _msgSender() || owner() == _msgSender(), "Not allowed");
        _mint(to, amount);
    }

    function burn(uint256 amount) public override(ISoul, ERC20Burnable) {}
}
