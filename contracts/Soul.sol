pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Soul is Ownable, ERC20Burnable {
    address public scionAddress;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function setScionAddress(address _scionAddress) external onlyOwner {
        scionAddress = _scionAddress;
    }

    function mint(address to, uint256 amount) external {
        require(scionAddress == _msgSender() || owner() == _msgSender(), "Not allowed");
        _mint(to, amount);
    }
}
