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

You can find transactions for using the Flow Token in the `transactions/FlowToken` directory.

### Fee Contract

`contracts/FlowFees.cdc`

This contract defines fees that are spent for executing transactions and creating accounts.

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

You can find all the transactions for interacting with the IDTableStaking contract
in the `transactions/idTableStaking` directory.

### Flow Staking Helper Contract

`contracts/FlowStakingHelper.cdc`

The Flow staking helper contract manages the relationship between a user who wants to operate a node
and a token holder who wants to stake all their tokens for them. The staking helper contract draft is
in the `max/staking-helper` branch in a PR and will be merged very soon.

You can find all the Staking Helper transactions in the `transactions/stakingHelper` directory.

## Testing

To run the tests in the repo, run `cd lib/go/test && go test -v`.

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
        // Use the templates package to get the transaction script,
        // providing the import addresses for the contract imports
        SetScript(templates.GenerateCreateNodeScript(emulatorFTAddress, emulatorFlowTokenAddress, IDTableAddr.String())).
        SetGasLimit(100).
        SetProposalKey(b.ServiceKey().Address, b.ServiceKey().ID, b.ServiceKey().SequenceNumber).
        SetPayer(b.ServiceKey().Address).
        AddAuthorizer(IDTableAddr)

    _ = tx.AddArgument(cadence.NewString(firstID))
    _ = tx.AddArgument(cadence.NewUInt8(1))
    _ = tx.AddArgument(cadence.NewString("12234"))
    _ = tx.AddArgument(cadence.NewString("netkey"))
    _ = tx.AddArgument(cadence.NewString("stakekey"))
    tokenAmount, err := cadence.NewUFix64("250000.0")
    require.NoError(t, err)
    _ = tx.AddArgument(tokenAmount)
    cut, err := cadence.NewUFix64("1.0")
    require.NoError(t, err)
    _ = tx.AddArgument(cut)
```

### Packages in other languages

We are planning to add new packages for other popular languages to get transaction templates.
If you would like to contribute to add one of these new packages, please reach out
to the team and we would be happy to help!

## License 

The works in these folders are under the [Unlicense](https://github.com/dapperlabs/flow-core-contracts/blob/master/LICENSE):

- [src/contracts](https://github.com/dapperlabs/flow-core-contracts/tree/master/contracts)


