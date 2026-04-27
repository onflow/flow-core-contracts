# flow-core-contracts — Cadence Protocol Contracts for the Flow Network

[![License](https://img.shields.io/github/license/onflow/flow-core-contracts)](https://github.com/onflow/flow-core-contracts/blob/master/LICENSE)
[![Release](https://img.shields.io/github/v/release/onflow/flow-core-contracts?include_prereleases)](https://github.com/onflow/flow-core-contracts/releases)
[![Discord](https://img.shields.io/discord/613813861610684416?label=Discord&logo=discord)](https://discord.gg/flow)
[![Built on Flow](https://img.shields.io/badge/Built%20on-Flow-00EF8B)](https://flow.com)
[![Go Reference](https://pkg.go.dev/badge/github.com/onflow/flow-core-contracts/lib/go/templates.svg)](https://pkg.go.dev/github.com/onflow/flow-core-contracts/lib/go/templates)

## TL;DR

- **What:** Cadence smart contracts that define core protocol functionality of the Flow network, including FLOW token, staking, delegation, epochs, service account, fees, scheduled transactions, and random beacon history.
- **Who it's for:** Flow node operators, staking and delegation service builders, protocol researchers, and Cadence developers integrating with Flow protocol contracts.
- **Why use it:** Canonical source of the protocol-level contracts deployed to Flow networks (Emulator, Testnet, Mainnet), plus reusable Cadence transaction templates and a Go template package.
- **Status:** see [Releases](https://github.com/onflow/flow-core-contracts/releases) for the latest version.
- **License:** Unlicense.
- **Related repos:** [onflow/cadence](https://github.com/onflow/cadence), [onflow/flow-go](https://github.com/onflow/flow-go), [onflow/flow-ft](https://github.com/onflow/flow-ft)
- The reference set of core staking and token contracts for the Flow network, open-sourced since 2020.

# What is Flow?

Flow is a Layer 1 blockchain built for consumer applications, AI Agents, and DeFi at scale. Read more at [flow.com](https://flow.com).

# What is Cadence?

Cadence is a resource-oriented programming language
for developing smart contracts for the Flow network.
Read more about it at [cadence-lang.org](https://cadence-lang.org).

We recommend that anyone who is reading this should have already
completed the [Cadence Tutorials](https://cadence-lang.org/docs/tutorial/first-steps)
so they can build a basic understanding of the programming language.

## FlowToken

`contracts/FlowToken.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0x0ae53cb6e3f42a79` |
| Testnet  | `0x7e60df042a9c0868` |
| Mainnet  | `0x1654653399040a61` |

This is the contract that defines the network token for Flow.
This token is used for account creation fees, transaction fees, staking, and more. It is
implemented as a regular smart contract so that it can be easily used
just like any other token in the network. See the [flow fungible token repository](https://github.com/onflow/flow-ft)
for more information.

You can find transactions for using the Flow Token in the `transactions/flowToken` directory.

## Flow Transaction Fee Contract

`contracts/FlowFees.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xe5a8b7f23e8b548f` |
| Testnet  | `0x912d5440f7e3769e` |
| Mainnet  | `0xf919ee77447b7497` |

This contract defines fees that are spent for executing transactions and creating accounts.

## Storage Fee Contract

`contracts/FlowStorageFees.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testnet  | `0x8c5303eaa26202d6` |
| Mainnet  | `0xe467b9dd11fa00df` |

This contract defines fees that are spent to pay for the storage that an account uses.
There is a minimum balance that an account needs to maintain in its main `FlowToken` Vault
in order to pay for the storage it uses.
You can see [more docs about storage capacity and fees here.](https://developers.flow.com/build/basics/fees)

## Service Account Contract

`contracts/FlowServiceAccount.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testnet  | `0x8c5303eaa26202d6` |
| Mainnet  | `0xe467b9dd11fa00df` |

This contract manages account creation and flow token initialization and contains other utils for fees.

You can find transactions for interacting with the service account contract in the `transactions/FlowServiceAccount` directory.

## Scheduled Transactions Contracts

`contracts/FlowTransactionScheduler.cdc`
`contracts/FlowTransactionSchedulerUtils.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testnet  | `0x8c5303eaa26202d6` |
| Mainnet  | `0xe467b9dd11fa00df` |

These contracts manage scheduled transaction functionality. 

You can find transactions for interacting with the scheduled transactions contracts in the `transactions/transactionScheduler/` directory.

[Scheduled Transaction Docs](https://developers.flow.com/blockchain-development-tutorials/forte/scheduled-transactions/scheduled-transactions-introduction)

## Random Beacon History Contract

`contracts/RandomBeaconHistory.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testnet  | `0x8c5303eaa26202d6` |
| Mainnet  | `0xe467b9dd11fa00df` |

This contract stores the history of random sources generated by
the Flow network. The defined Heartbeat resource is
updated by the Flow Service Account at the end of every block
with that block's source of randomness.

You can find transactions for interacting with the random beacon
 history contract in the `transactions/randomBeaconHistory` directory.

## Node Version Beacon Contract

`contracts/NodeVersionBeacon.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testnet  | `0x8c5303eaa26202d6` |
| Mainnet  | `0xe467b9dd11fa00df` |

The `NodeVersionBeacon` contract holds the past
and future protocol versions that should be used
to execute/handle blocks at a given block height.

You can find transactions for interacting with the node version beacon
history contract in the `transactions/nodeVersionBeacon` directory.

## Flow Epochs, Identity Table, and Staking Contracts

`contracts/FlowIDTableStaking.cdc`
`contracts/epochs/FlowEpoch.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testnet  | `0x9eca2b38b18b5dfe` |
| Mainnet  | `0x8624b52f9ddcd04a` |

These contract manages the list of identities that correspond to node operators in the Flow network
as well as the process for adding and removing nodes from the network via Epochs.
Each node identity stakes tokens with these contracts, and also gets paid rewards with their contracts.
This contract also manages the logic for users to delegate their tokens to a node operator
and receive their own rewards. You can see an explanation of this process in the staking section
of the [Flow Docs website](https://developers.flow.com/networks/staking).

You can find all the transactions for interacting with the IDTableStaking contract with unlocked FLOW
in the `transactions/idTableStaking` directory, though it is recommended to use the staking collection
transactions instead. These are described in the "Flow Staking Collection" section below.

You can also find transactions and scripts for interacting
with all the epoch smart contracts in the following directories:
`transactions/epoch/`
`transactions/dkg/`
`transactions/quorumCertificate/`

You can also find scripts for querying info about staking and stakers in the `transactions/idTableStaking/scripts/` directory.
These scripts are documented in the [staking scripts section of the docs](https://developers.flow.com/networks/staking/staking-scripts-events)

## Flow Locked Tokens contract

`contracts/LockedTokens.cdc`

| Network  | Contract Address     |
| ---------| -------------------- |
| Emulator | `0xf8d6e0586b0a20c7` |
| Testnet  | `0x95e019a17d0e23d7` |
| Mainnet  | `0x8d0e87b65159ae63` |

This contract manages the two year lockup of Flow tokens that backers purchased in the initial
token sale in October of 2020. See more documentation about `LockedTokens` [here.](https://developers.flow.com/networks/staking/staking-options)

## Flow Staking Collection Contract

`contracts/FlowStakingCollection.cdc`

The `StakingCollection` contract has the same import addresses
as the `LockedTokens` contract on all the networks.

A Staking Collection is a resource that allows its owner to manage multiple staking
objects in a single account via a single storage path, and perform staking and delegation actions using both locked and unlocked Flow.

Before the staking collection, accounts could use the instructions in [the unlocked staking guide](https://developers.flow.com/networks/staking/staking-options)
to stake with tokens. This was a bit restrictive, because that guide (and the corresponding transactions) only supports one node and one delegator object
per account. If a user wanted to have more than one per account, they would either have to use custom transactions with custom storage paths for each object,
or they would have had to use multiple accounts, which comes with many hassles of its own.

The same applies to the [locked tokens staking guide](https://developers.flow.com/networks/staking/staking-options).
We only built in support for one node and one delegator per account.

The staking collection is a solution to both of these deficiencies. When an account is set up to use a staking collection,
the staking collection recognizes the existing locked account capabilities (if they exist) and unlocked account staking objects,
and incorporates their functionality so any user can stake for a node or delegator through a single common interface, regardless of
if they have a brand new account, or have been staking through the locked account or unlocked account before.

### Is the staking collection mandatory

Flow Port uses staking collection transaction by default other services are encouraged
to use it instead of any of the other account staking setups.
If you provide a staking service for [Ledger](https://www.ledger.com/) or [Blocto](https://blocto.io/download) users, you will need to upgrade
to this if you want to give your users access to the entire functionality of their account
if they are also using Flow Port. If their entire interaction with staking is through Flow Port,
then all the changes are handled for them and there is nothing for you to worry about.

### Staking Collection Technical features

* The staking collection contract stores [a dictionary of staking objects](https://github.com/onflow/flow-core-contracts/blob/master/contracts/FlowStakingCollection.cdc#L68) from the staking contract that are used to manage the stakers tokens. Since they are dictionaries, there can be as many node or delegator objects per account as the user wants.
* The resource only has one set of staking methods, which route the call to the correct staking object based on the arguments that the caller specifies. (nodeID, delegatorID)
* The contract also stores an [optional capability to the locked token vault](https://github.com/onflow/flow-core-contracts/blob/master/contracts/FlowStakingCollection.cdc#L63) and [locked tokens `TokenHolder` resource](https://github.com/onflow/flow-core-contracts/blob/master/contracts/FlowStakingCollection.cdc#L73). This is only used if the user already has a locked account. The staking collection does not change the locked account setup at all, it only has access to it and to the locked vault.
* The collection makes the staking objects and vault capability fields private, because since it has access to the locked tokens, it needs to mediate access to the staking objects so users cannot withdraw tokens that are still locked from the sale. The resource has fields `unlockedTokensUsed` and `lockedTokensUsed`, to keep track of how many locked and unlocked tokens are being used for staking in order to allow the user to withdraw the correct amount when they choose to.
* The staking collection contract is a brand new contract that will be deployed to the same account as the existing locked tokens contract. A few of the fields on the `LockedTokens` contract have been updated to have `access(account)` visibility instead of `access(self)` because the staking collection contract needs to be able to access to them in order to work properly.
* We also included a public interface and getters in the contract so you can easily query it with an address to get node or delegator information from a collection.

Looking for feedback on design decisions, implementation details, any events that would be useful to include in the contract, and whatever you feel is important!

We intend for this to be the method that all Flow Port users (ledger, blocto, etc) use for the forseeable future. When we enable it in Flow Port, we will ask every user to run a transaction to set up their account to use the staking collection from then on.

## Linear Code Address Generator

`contracts/LinearCodeAddressGenerator.cdc`

The linear code address generator contract allows translating an address index to an address,
and and address back to an address index.
It implements the same address generation logic as used on all Flow networks.

# Testing

To run the tests in the repo, use `make test`.

These tests need to utilize the transaction templates that are contained in `transactions/`.

# Audit

Flow Core Contracts were audited by Quantstamp in July 2021: [final report](https://certificate.quantstamp.com/full/epoch-functionality-contracts.pdf).

# Getting Transaction Templates

If you need to use the contracts and transaction templates we have provided in an app, you don't necessarily
need to copy and paste them into your code. We plan on providing packages for different
languages to import in order to use the transactions instead of copying and pasting.

We currently include the `lib/go/templates` package for getting templates in the Go programming language.
To use this package, run `go get github.com/onflow/flow-core-contracts/lib/go/templates@{latest version}`
in your Go project direcory. To use it in your Go code, you can simply call one of the many
template getters in one of the `*_templates.go` files.

### Packages in other languages

We would like to add new packages for other popular languages to get transaction templates.
If you would like to contribute to add one of these new packages, please reach out
to the team and we would be happy to help!

## License

The works in these folders are under the [Unlicense](https://github.com/onflow/flow-core-contracts/blob/master/LICENSE):

- [contracts](https://github.com/onflow/flow-core-contracts/tree/master/contracts)

## FAQ

**Q: What is in this repository?**
A: Cadence smart contracts that define core protocol functionality on the Flow network (FLOW token, fees, staking, delegation, epochs, service account, scheduled transactions, random beacon history, and related utilities) plus transaction templates for interacting with them.

**Q: Where are these contracts deployed?**
A: Addresses for Emulator, Testnet, and Mainnet deployments are listed alongside each contract section in this README.

**Q: How do I run the tests?**
A: Run `make test` from the repository root. Tests rely on the transaction templates in the `transactions/` directory.

**Q: How can I use the transaction templates from Go?**
A: Import the `lib/go/templates` package (`go get github.com/onflow/flow-core-contracts/lib/go/templates@<version>`) and call the template getters exposed by the `*_templates.go` files.

**Q: Which staking setup should new integrations use?**
A: The Staking Collection is recommended. It supports multiple node or delegator objects per account and unifies the locked and unlocked staking flows behind a single interface.

**Q: Where can I learn more about Cadence?**
A: See the Cadence language reference at [cadence-lang.org](https://cadence-lang.org).

**Q: Where can I read the formal audit report?**
A: Flow Core Contracts were audited by Quantstamp in July 2021; the [final report](https://certificate.quantstamp.com/full/epoch-functionality-contracts.pdf) is linked in the Audit section above.

## About Flow

This repo is part of the [Flow network](https://flow.com), a Layer 1 blockchain built for consumer applications, AI Agents, and DeFi at scale.

- Developer docs: https://developers.flow.com
- Cadence language: https://cadence-lang.org
- Community: [Flow Discord](https://discord.gg/flow) · [Flow Forum](https://forum.flow.com)
- Governance: [Flow Improvement Proposals](https://github.com/onflow/flips)
