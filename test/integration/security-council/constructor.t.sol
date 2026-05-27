// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Base_Test } from "../../Base.t.sol";

contract Constructor_Integration_Concrete_Test is Base_Test {
    function test_MultisigIsOwner_AtDeployment() public view {
        // owner right after deploy, no acceptOwnership() needed
        assertEq(securityCouncil.owner(), users.securityCouncilMultisig);
    }
}
