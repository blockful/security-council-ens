// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { SecurityCouncil } from "../src/SecurityCouncil.sol";
import { ITimelock } from "../src/interfaces/ITimelock.sol";
import { IRegistry } from "../src/interfaces/IRegistry.sol";

/// @notice Deploys the SecurityCouncil contract to mainnet.
///
/// Required env vars:
///   - SECURITY_COUNCIL_MULTISIG: address of the 4/8 Security Council multisig
///   - PRIVATE_KEY: deployer key (broadcast)
///
/// Usage:
///   forge script script/Deploy.s.sol:Deploy \
///     --rpc-url $RPC_URL_MAINNET \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $ETHERSCAN_API_KEY
///
/// After deployment, the ENS DAO must pass a proposal that calls
/// `timelock.grantRole(PROPOSER_ROLE, <deployed_address>)`.
contract Deploy is Script {
    // Mainnet ENS infrastructure.
    address constant ENS_TIMELOCK = 0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7;
    address constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;

    function run() external returns (SecurityCouncil securityCouncil) {
        address multisig = vm.envAddress("SECURITY_COUNCIL_MULTISIG");
        require(multisig != address(0), "Deploy: multisig is zero address");

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);
        securityCouncil = new SecurityCouncil(multisig, ITimelock(payable(ENS_TIMELOCK)), IRegistry(ENS_REGISTRY));
        vm.stopBroadcast();

        console2.log("SecurityCouncil deployed at:", address(securityCouncil));
        console2.log("  multisig (owner):", securityCouncil.owner());
        console2.log("  timelock:", address(securityCouncil.timelock()));
        console2.log("  expiration (unix):", securityCouncil.expiration());
        console2.log("");
        console2.log("Next step: ENS DAO must grant PROPOSER_ROLE to this address via governance proposal.");
    }
}
