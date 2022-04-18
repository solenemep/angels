pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Keter is ERC20 {
    constructor() ERC20("Keter", "Keter") {
        _mint(msg.sender, 1000000000e18);
    }
}