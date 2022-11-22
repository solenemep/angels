pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Keter is Ownable, ERC20 {
    constructor() ERC20("Keter", "Keter") {
        _mint(msg.sender, 1000000e18);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
