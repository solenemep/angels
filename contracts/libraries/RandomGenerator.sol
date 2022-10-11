// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

/// @notice the intention of this library is to be able to generate random number

library RandomGenerator {
    function random(
        address user,
        uint256 _limit,
        uint256 _salt
    ) external view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, user, _salt))) %
            _limit;
    }
}
