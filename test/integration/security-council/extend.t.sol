// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { SecurityCouncil } from "../../../src/SecurityCouncil.sol";
import { Security_Council_Integration_Concrete_Test } from "./securityCouncil.t.sol";
import { Veto_Integration_Concrete_Test } from "./veto.t.sol";

contract Extend_Integration_Concrete_Test is Security_Council_Integration_Concrete_Test {
    function test_Extend_ByTimelock_Success() public {
        uint256 currentExpiration = securityCouncil.expiration();
        uint256 newExpiration = currentExpiration + 365 days;

        vm.prank(address(timelock));
        securityCouncil.extend(newExpiration);

        assertEq(securityCouncil.expiration(), newExpiration);
    }

    function test_Revert_Extend_ByRandomUser() public {
        uint256 newExpiration = securityCouncil.expiration() + 365 days;

        vm.expectRevert(SecurityCouncil.OnlyTimelock.selector);
        vm.prank(users.alice);
        securityCouncil.extend(newExpiration);
    }

    function test_Revert_Extend_BySecurityCouncilMultisig() public {
        uint256 newExpiration = securityCouncil.expiration() + 365 days;

        // owner can't extend itself, only the DAO can
        vm.expectRevert(SecurityCouncil.OnlyTimelock.selector);
        vm.prank(users.securityCouncilMultisig);
        securityCouncil.extend(newExpiration);
    }

    function test_Revert_Extend_WithEqualExpiration() public {
        uint256 currentExpiration = securityCouncil.expiration();

        vm.expectRevert(SecurityCouncil.InvalidExpiration.selector);
        vm.prank(address(timelock));
        securityCouncil.extend(currentExpiration);
    }

    function test_Revert_Extend_WithLowerExpiration() public {
        uint256 currentExpiration = securityCouncil.expiration();

        vm.expectRevert(SecurityCouncil.InvalidExpiration.selector);
        vm.prank(address(timelock));
        securityCouncil.extend(currentExpiration - 1);
    }

    function test_Revert_RenounceTimelockRole_BeforeNewExpiration() public {
        uint256 originalExpiration = securityCouncil.expiration();
        uint256 newExpiration = originalExpiration + 365 days;

        vm.prank(address(timelock));
        securityCouncil.extend(newExpiration);

        // renounce now has to wait for the new expiration
        vm.warp(newExpiration - 1);
        vm.expectRevert(SecurityCouncil.ExpirationNotReached.selector);
        securityCouncil.renounceTimelockRoleByExpiration();
    }

    function test_RenounceTimelockRole_AtNewExpiration() public {
        uint256 originalExpiration = securityCouncil.expiration();
        uint256 newExpiration = originalExpiration + 365 days;

        vm.prank(address(timelock));
        securityCouncil.extend(newExpiration);

        vm.warp(newExpiration);
        securityCouncil.renounceTimelockRoleByExpiration();

        assertFalse(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)));
    }

    function test_Revert_Extend_AfterRoleRenounced() public {
        // renounce can win the race past expiration. once the role is gone,
        // extend should revert instead of bumping a dead number
        uint256 originalExpiration = securityCouncil.expiration();
        vm.warp(originalExpiration);

        securityCouncil.renounceTimelockRoleByExpiration();
        assertFalse(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)));

        vm.expectRevert(SecurityCouncil.RoleAlreadyRenounced.selector);
        vm.prank(address(timelock));
        securityCouncil.extend(block.timestamp + 365 days);
    }

    function test_Revert_Extend_WithPastTimestamp() public {
        // newExpiration beats the old expiration but is still in the past,
        // so it should revert
        uint256 originalExpiration = securityCouncil.expiration();
        vm.warp(originalExpiration + 100 days);

        // > expiration, < now
        uint256 staleNewExpiration = originalExpiration + 1;
        assertTrue(staleNewExpiration > securityCouncil.expiration());
        assertTrue(staleNewExpiration < block.timestamp);

        vm.expectRevert(SecurityCouncil.InvalidExpiration.selector);
        vm.prank(address(timelock));
        securityCouncil.extend(staleNewExpiration);
    }

    function test_Extend_AfterOriginalExpiration_BeforeRenounce() public {
        uint256 originalExpiration = securityCouncil.expiration();
        uint256 newExpiration = originalExpiration + 365 days;

        // expired but nobody renounced yet
        vm.warp(originalExpiration + 1);
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(securityCouncil)));

        // DAO can still extend here
        vm.prank(address(timelock));
        securityCouncil.extend(newExpiration);

        assertEq(securityCouncil.expiration(), newExpiration);

        // back inside the term, so renounce reverts
        vm.expectRevert(SecurityCouncil.ExpirationNotReached.selector);
        securityCouncil.renounceTimelockRoleByExpiration();
    }
}

/// reuses the veto setUp so there's a real queued op to cancel
contract Extend_With_Queued_Proposal_Integration_Concrete_Test is Veto_Integration_Concrete_Test {
    function test_Extend_VetoCancelsRealProposal_PastOriginalExpiration() public {
        uint256 originalExpiration = securityCouncil.expiration();
        uint256 newExpiration = originalExpiration + 365 days;

        // extend before the original expiration
        vm.prank(address(timelock));
        securityCouncil.extend(newExpiration);

        // past the old expiration, before the new one
        vm.warp(originalExpiration + 1);

        // still queued
        assertTrue(timelock.isOperation(proposalIdInTimelock));

        // veto should still work and actually cancel it
        vm.prank(users.securityCouncilMultisig);
        securityCouncil.veto(proposalIdInTimelock);

        assertFalse(timelock.isOperation(proposalIdInTimelock));
    }
}
