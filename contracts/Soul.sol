pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Soul is ERC20 {
    constructor() ERC20("SOUL", "SOUL") {
        _mint(msg.sender, 1000000000e18);
    }
}