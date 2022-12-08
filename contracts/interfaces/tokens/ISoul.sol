// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface ISoul is IERC20Metadata {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}
