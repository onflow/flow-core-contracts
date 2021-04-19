# Flow Core Smart Contracts

These are the smart contracts that define the core functionality of the Flow protocol.

## What is Flow?

Flow is a new blockchain for open worlds. Read more about it [here](https://www.onflow.org/).

## What is Cadence?

Cadence is a new Resource-oriented programming language 
for developing smart contracts for the Flow Blockchain.
Read more about it [here](https://www.docs.onflow.org)

We recommend that anyone who is reading this should have already
completed the [Cadence Tutorials](https://docs.onflow.org/docs/getting-started-1) 
so they can build a basic understanding of the programming language.

### FlowToken

`contracts/FlowToken.cdc`

This is the contract that defines the network token for Flow. 
This token is used for account creation fees, transaction fees, staking, and more. It is 
implemented as a regular smart contract so that it can be easily used 
just like any other token in the network. See the [flow fungible token repository](https://github.com/onflow/flow-ft)
for more information.

You can find transactions for using the Flow Token in the `transactions/flowToken` directory.

### Fee Contract

`contracts/FlowFees.cdc`

This contract defines fees that are spent for executing transactions and creating accounts.

### Storage Fee Contract

`contracts/FlowStorageFees.cdc`

This contract defines fees that are spent to pay for the storage that an account uses.
There is a minimum balance that an account needs to maintain in its main `FlowToken` Vault
in order to pay for the storage it uses.
You can see [more docs about storage capacity and fees here.](https://docs.onflow.org/concepts/storage/#overview)

### Service Account Contract

`contracts/FlowServiceAccount.cdc`

This contract manages account creation and flow token initialization. It enforces temporary
requirements for which accounts are allowed to create other accounts, and provides common
functionality for flow tokens.

You can find transactions for interacting with the service account contract in the `transactions/FlowServiceAccount` directory.

### Flow Identity Table, Staking, and Delegation Contract

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

### Flow Locked Tokens contract

`contracts/LockedTokens.cdc`

This contract manages the two year lockup of Flow tokens that backers purchased in the initial
token sale in October of 2020. See more documentation about `LockedTokens` [here.](https://docs.onflow.org/flow-token/locked-account-setup/)

## Testing

To run the tests in the repo, use `make test`.

These tests need to utilize the transaction templates that are contained in `transactions/`.

## Getting Transaction Templates

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
