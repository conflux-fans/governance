//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IPoSPool {
    function userVotePower(address user) external view returns (uint256);
}