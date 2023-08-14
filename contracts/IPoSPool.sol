//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IPoSPool {
    struct UserSummary {
        uint64 votes;  // Total votes in PoS system, including locking, locked, unlocking, unlocked
        uint64 available; // locking + locked
        uint64 locked;
        uint64 unlocked;
        uint256 claimedInterest;
        uint256 currentInterest;
    }

    function userVotePower(address user) external view returns (uint256);
    function userSummary(address _user) external view returns (UserSummary memory);
}