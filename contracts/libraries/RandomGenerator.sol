// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @notice the intention of this library is to be able to generate random number

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

library RandomGenerator {
    using SafeMath for uint256;

    function random(
        address _user,
        uint256 _limit,
        uint256 _salt
    ) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, _user, _salt))) %
            _limit;
    }
}
