# Flow Core Smart Contracts

These are the smart contracts that define the core functionality of the Flow protocol.

# What is Flow?

Flow is a new blockchain for open worlds. Read more about it [here](https://www.onflow.org/).

# What is Cadence?

Cadence is a new Resource-oriented programming language 
for developing smart contracts for the Flow Blockchain.
Read more about it [here](https://www.docs.onflow.org)

We recommend that anyone who is reading this should have already
completed the [Cadence Tutorials](https://docs.onflow.org/docs/getting-started-1) 
so they can build a basic understanding of the programming language.

## FlowToken

`contracts/FlowToken.cdc`

This is the contract that defines the network token for Flow. 
This token is used for account creation fees, transaction fees, staking, and more. It is 
implemented as a regular smart contract so that it can be easily used 
just like any other token in the network. See the [flow fungible token repository](https://github.com/onflow/flow-ft)
for more information.

You can find transactions for using the Flow Token in the `transactions/flowToken` directory.

## Fee Contract

`contracts/FlowFees.cdc`

This contract defines fees that are spent for executing transactions and creating accounts.

## Storage Fee Contract

`contracts/FlowStorageFees.cdc`

This contract defines fees that are spent to pay for the storage that an account uses.
There is a minimum balance that an account needs to maintain in its main `FlowToken` Vault
in order to pay for the storage it uses.
You can see [more docs about storage capacity and fees here.](https://docs.onflow.org/concepts/storage/#overview)

## Service Account Contract

`contracts/FlowServiceAccount.cdc`

This contract manages account creation and flow token initialization. It enforces temporary
requirements for which accounts are allowed to create other accounts, and provides common
functionality for flow tokens.

You can find transactions for interacting with the service account contract in the `transactions/FlowServiceAccount` directory.

## Flow Identity Table, Staking, and Delegation Contract

`contracts/FlowIDTableStaking.cdc`

This contract manages the list of identities that correspond to node operators in the Flow network.
Each node identity stakes tokens with this contract, and also gets paid rewards with this contract.
This contract also manages the logic for users to delegate their tokens to a node operator
and receive their own rewards. You can see an explaination of this process in the staking section
of the [Flow Docs website](https://docs.onflow.org/token/staking/).

You can find all the transactions for interacting with the IDTableStaking contract with unlocked FLOW
in the `transactions/idTableStaking` directory.

You can also find scripts for querying info about staking and stakers in the `transactions/idTableStaking/scripts/` directory.
These scripts are documented in the [staking scripts section of the docs](https://docs.onflow.org/staking/scripts/)

## Flow Locked Tokens contract

`contracts/LockedTokens.cdc`

This contract manages the two year lockup of Flow tokens that backers purchased in the initial
token sale in October of 2020. See more documentation about `LockedTokens` [here.](https://docs.onflow.org/flow-token/locked-account-setup/)

## Flow Staking Collection Contract

`contracts/FlowStakingCollection.cdc`

A Staking Collection is a resource that allows its owner to manage multiple staking
objects in a single account via a single storage path, and perform staking and delegation actions using both locked and unlocked Flow.

Before the staking collection, accounts could use the instructions in [the unlocked staking guide](https://docs.onflow.org/staking/unlocked-staking-guide/)
to stake with tokens. This was a bit restrictive, because that guide (and the corresponding transactions) only supports one node and one delegator object
per account. If a user wanted to have more than one per account, they would either have to use custom transactions with custom storage paths for each object,
or they would have had to use multiple accounts, which comes with many hassles of its own.

The same applies to the [locked tokens staking guide](https://docs.onflow.org/staking/locked-staking-guide/).
We only built in support for one node and one delegator per account.

The staking collection is a solution to both of these deficiencies. When an account is set up to use a staking collection,
the staking collection recognizes the existing locked account capabilities (if they exist) and unlocked account staking objects,
and incorporates their functionality so any user can stake for a node or delegator through a single common interface, regardless of
if they have a brand new account, or have been staking through the locked account or unlocked account before.

### Is the staking collection mandatory

The Flow team will be using the staking collection for Flow Port by default and we recommend that other services use it instead of any of the other account setups. If you provide a staking service for ledger or blocto users, you will need to upgrade to this if you want to give your users access to the entire functionality of their account if they are also using Flow Port. If their entire interaction with staking is through Flow Port, then all the changes are handled for them and there is nothing for you to worry about.

### Staking Collection Technical features

* The staking collection contract stores [a dictionary of staking objects](https://github.com/onflow/flow-core-contracts/blob/master/contracts/FlowStakingCollection.cdc#L68) from the staking contract that are used to manage the stakers tokens. Since they are dictionaries, there can be as many node or delegator objects per account as the user wants. 
* The resource only has one set of staking methods, which route the call to the correct staking object based on the arguments that the caller specifies. (nodeID, delegatorID)
* The contract also stores an [optional capability to the locked token vault](https://github.com/onflow/flow-core-contracts/blob/master/contracts/FlowStakingCollection.cdc#L63) and [locked tokens `TokenHolder` resource](https://github.com/onflow/flow-core-contracts/blob/master/ontracts/FlowStakingCollection.cdc#L73). This is only used if the user already has a locked account. The staking collection does not change the locked account setup at all, it only has access to it and to the locked vault.
* The collection makes the staking objects and vault capability fields private, because since it has access to the locked tokens, it needs to mediate access to the staking objects so users cannot withdraw tokens that are still locked from the sale. The resource has fields `unlockedTokensUsed` and `lockedTokensUsed`, to keep track of how many locked and unlocked tokens are being used for staking in order to allow the user to withdraw the correct amount when they choose to.
* The staking collection contract is a brand new contract that will be deployed to the same account as the existing locked tokens contract. A few of the fields on the `LockedTokens` contract have been updated to have `access(account)` visibility instead of `access(self)` because the staking collection contract needs to be able to access to them in order to work properly.
* We also included a public interface and getters in the contract so you can easily query it with an address to get node or delegator information from a collection. 

Looking for feedback on design decisions, implementation details, any events that would be useful to include in the contract, and whatever you feel is important!

We intend for this to be the method that all Flow Port users (ledger, blocto, etc) use for the forseeable future. When we enable it in Flow Port, we will ask every user to run a transaction to set up their account to use the staking collection from then on. 


## Epoch Contracts

`contracts/epochs/FlowEpoch.cdc`
`contracts/epochs/FlowClusterQC.cdc`
`contracts/epochs/FlowDKG.cdc`

These contracts manage the epoch functionality of Flow, the mechanism by which Flow tracks time, changes the approved list of node operators, and bootstrap consensus between different nodes. 
`FlowClusterQC.cdc` and `FlowDKG.cdc` manage processes specific to collector and consensus nodes, respectively.
`FlowEpoch.cdc` ties all of the epoch and staking contracts together into a coherent state machine that will run on its own.

# Testing

To run the tests in the repo, use `make test`.

These tests need to utilize the transaction templates that are contained in `transactions/`.

# Getting Transaction Templates

If you need to use the contracts and transaction templates we have provided in an app, you don't necessarily 
need to copy and paste them into your code. We plan on providing packages for different
languages to import in order to use the transactions instead of copying and pasting.

We currently include the `lib/go/templates` package for getting templates in the Go programming language.
To use this package, run `import github.com/onflow/flow-core-contracts/lib/go/templates@{latest version}`
in your Go project direcory. To use it in your Go code, you can simply call one of the many 
template getters in one of the `*_templates.go` files. 

For example, to get the transaction text of the tranasction that is used to register a new node
for staking, and add arguments to it, you would use something like this Go code.

```Go
    tx := flow.NewTransaction().
        SetScript(templates.GenerateRegisterNodeScript(env)).
        SetGasLimit(100).
        SetProposalKey(b.ServiceKey().Address, b.ServiceKey().Index, b.ServiceKey().SequenceNumber).
        SetPayer(b.ServiceKey().Address).
        AddAuthorizer(userAddress)

    // Invalid ID: Too short
    _ = tx.AddArgument(cadence.NewString("3039"))
    _ = tx.AddArgument(cadence.NewUInt8(1))
    _ = tx.AddArgument(cadence.NewString("12234"))
    _ = tx.AddArgument(cadence.NewString("netkey"))
    _ = tx.AddArgument(cadence.NewString("stakekey"))
    tokenAmount, err := cadence.NewUFix64("250000.0")
    require.NoError(t, err)
    _ = tx.AddArgument(tokenAmount)
```

### Packages in other languages

We are planning to add new packages for other popular languages to get transaction templates.
If you would like to contribute to add one of these new packages, please reach out
to the team and we would be happy to help!

## License 

The works in these folders are under the [Unlicense](https://github.com/dapperlabs/flow-core-contracts/blob/master/LICENSE):

- [src/contracts](https://github.com/dapperlabs/flow-core-contracts/tree/master/contracts)
