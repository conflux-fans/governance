//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ICoreSpaceInfo {
    function blockNumber() external view returns (uint256);
    function currentVoteRound() external view returns (uint64);
}