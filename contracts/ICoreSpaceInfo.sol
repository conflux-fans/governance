//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ICoreSpaceInfo {
    function coreSpaceBlockNumber() external view returns (uint256);
    function coreSpaceVoteRound() external view returns (uint256);
}