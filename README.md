# SecurityCouncil

**SecurityCouncil** is a Solidity smart contract developed to fortify the governance of the Ethereum Name Service (ENS) DAO against potential threats to its treasury and protocol integrity. It implements a Security Council with the authority to cancel malicious proposals and features an expiration mechanism to prevent centralization of power. For more details on the proposal, please refer to [this document](link_to_full_proposal).

## Features

- **Proposal Cancellation**: Allows the Security Council multisig to cancel proposals within a timelock, mitigating the risk of malicious actions.
- **Expiration Mechanism**: Implements an expiration feature where the Security Council's veto power automatically expires after a specified time period (2 years), promoting decentralization.
- **DAO-Controlled Extension**: The DAO can extend the expiration through a governance proposal, so the council can stay past its original term without a redeploy.
- **Access Control**: Uses OpenZeppelin's `Ownable2Step`. The multisig owns the contract and is the only address that can call `veto`.

## Usage

To utilize the SecurityCouncil contract, follow these steps:

1. **Set security council multisig**: Deploy a 4/8 multisig.
2. **Deploy contract**: Deploy to Mainnet. The multisig is owner right away, no `acceptOwnership` call needed. Later owner changes still use the `Ownable2Step` propose/accept flow.
3. **Grant roles**: Grant `PROPOSER_ROLE` to the deployed contract from the timelock, through an Executable Proposal.
4. **Vetoing malicious proposals**: Once deployed and the role is granted, the council is live.
5. **Extending the term (optional)**: Before expiration, the DAO can pass a proposal that calls `extend(newExpiration)` from the timelock. No upper bound; each extension is its own vote. `extend` checks:
    - `newExpiration > current expiration`
    - `newExpiration > block.timestamp`, so stale calldata with a past date is rejected
    - the contract still holds `PROPOSER_ROLE`. If it was already renounced, re-grant it first
6. **Expiration management**: After expiration, anyone can call `renounceTimelockRoleByExpiration()` to drop the `PROPOSER_ROLE`, keeping the council time-limited.

## Running Tests with Mainnet Fork

1. **Setup .env File**: Create a `.env` file in the root directory of your project. Add the following line and replace `YOUR_RPC_URL_MAINNET` with your Mainnet RPC URL:
    ```env
    RPC_URL_MAINNET=YOUR_RPC_URL_MAINNET
    ```

2. **Run Tests**: Ensure you have [Foundry](https://github.com/dapp.tools/foundry) installed. Then, run the following command to execute tests with a Mainnet fork:
    ```bash
    forge test
    ```

## Deployment

`script/Deploy.s.sol` deploys to mainnet against the ENS timelock (`0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7`) and registry (`0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e`).

Env vars:
- `SECURITY_COUNCIL_MULTISIG`: the 4/8 multisig address
- `PRIVATE_KEY`: deployer key
- `RPC_URL_MAINNET`: mainnet RPC
- `ETHERSCAN_API_KEY`: for verification

```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url $RPC_URL_MAINNET \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

After deploying, the DAO grants `PROPOSER_ROLE` to the new address with a proposal.

## Security Considerations

Assigning the PROPOSER_ROLE to a multisig within the timelock contract is overly broad for our requirements as it allows the address to add proposals directly to the queue. If the multisig signers are compromised, they could potentially propose and execute malicious changes. Therefore, our approach would be to deploy a new contract similar to the current veto.ensdao.eth contract, which can only do one action: to CANCEL a transaction in the timelock. That would be a trivially simple contract and it would be hard locked to only accept calls from a newly created SAFE multisig.

With that in mind, ensuring the Security Council's multisig operates securely is essential. Availability of Signers and Secure Wallet Practices are crucial considerations for maintaining the integrity of the Security Council's operations.

The Security Council is expected to act only in emergencies and uphold the interests of the ENS DAO. Their responsibilities include understanding the ENS DAO thoroughly, listening to community feedback, taking quick action on behalf of the DAO, and comprehending the repercussions of approved proposals.

The Security Council members will be the same signers for the veto.ensdao.eth, their identities are known, have signed a pledge to uphold the ENS constitution, and reside in countries with a solid legal system.

## Security Audit

Nethermind Security conducted a security review of the `SecurityCouncil` contract (NM-0945), reporting zero points of attention. The full report is available at [audits/2026-06-05-Nethermind-Security-Review.pdf](audits/2026-06-05-Nethermind-Security-Review.pdf).

## License

This contract is available under the MIT license.
