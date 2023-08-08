// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract Mocks {
    function userVotePower(address user) external pure returns (uint256) {
        return 1000 ether;
    }

    function getVotePower(address user, uint256 blockNumber) external pure returns (uint256) {
        return 1000 ether;
    }
}