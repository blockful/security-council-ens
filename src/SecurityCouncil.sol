// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { ITimelock } from "./interfaces/ITimelock.sol";
import { IRegistry } from "./interfaces/IRegistry.sol";

import { ReverseClaimer } from "./ReverseClaimer.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title SecurityCouncil
 * @dev A contract to cancel proposals in the ENS timelock, controlled by the Security Council multisig.
 * @author Alexandro Netto - <alex@blockful.io>
 */
contract SecurityCouncil is ReverseClaimer, Ownable2Step {
    ITimelock public immutable timelock;
    uint256 public expiration;

    error ExpirationNotReached();
    error ExpirationReached();
    error OnlyTimelock();
    error InvalidExpiration();
    error RoleAlreadyRenounced();

    /**
     * @dev Constructor to initialize the contract with the Security Council multisig and timelock.
     * @param securityCouncilMultisig Address of the Security Council multisig.
     * @param _timelock Address of the timelock contract.
     * @param ensRegistry Address of the ENS registry.
     */
    constructor(
        address securityCouncilMultisig,
        ITimelock _timelock,
        IRegistry ensRegistry
    )
        ReverseClaimer(ensRegistry, msg.sender)
    {
        timelock = _timelock;

        // Set expiration to 2 years from deployment + voting period
        expiration = block.timestamp + (2 * 365 days) + 7 days;

        // owner from the start, no acceptOwnership() needed. later transfers
        // still use the 2-step flow
        _transferOwnership(securityCouncilMultisig);
    }

    /**
     * @dev Function to cancel a proposal in the timelock.
     * @param proposalId ID of the proposal to cancel.
     */
    function veto(bytes32 proposalId) external onlyOwner {
        require(block.timestamp < expiration, ExpirationReached());
        timelock.cancel(proposalId);
    }

    /**
     * @dev Extends the expiration. Only the timelock (DAO) can call it.
     * @param newExpiration New expiration, must be later than the current one.
     */
    function extend(uint256 newExpiration) external {
        require(msg.sender == address(timelock), OnlyTimelock());
        require(newExpiration > expiration, InvalidExpiration());
        // a past value is a no-op (usually stale calldata), so fail loud
        require(newExpiration > block.timestamp, InvalidExpiration());
        // once the role is renounced, extend would just bump a dead number.
        // make the DAO re-grant it first
        require(timelock.hasRole(timelock.PROPOSER_ROLE(), address(this)), RoleAlreadyRenounced());
        expiration = newExpiration;
    }

    /**
     * @dev Function to renounce the veto role after expiration.
     */
    function renounceTimelockRoleByExpiration() external {
        require(block.timestamp >= expiration, ExpirationNotReached());
        timelock.renounceRole(timelock.PROPOSER_ROLE(), address(this));
    }
}
