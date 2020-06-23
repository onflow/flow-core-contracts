# Flow Core Smart Contracts

These are the smart contracts that define the core functionality of the Flow protocol.

### FlowToken

`contracts/FlowToken.cdc`

This is the contract that defines the network token for Flow. 
This token is used for account creation fees, transaction fees, staking, and more. It is 
implemented as a regular smart contract so that it can be easily used 
just like any other token in the network. See the [flow fungible token repository](https://github.com/onflow/flow-ft)
for more information.

### Fee Contract

`contracts/FlowFees.cdc`

This contract accepts fees that are spent for executing transactions and creating accounts.

### Service Account Contract

`contracts/FlowServiceAccount.cdc`

This contract manages account creation and flow token initialization. It enforces temporary
requirements for which accounts are allowed to create other accounts, and provides common
functionality for flow tokens.

## Testing

To run the tests in the repo, run `cd lib/go/test && go test -v`.

These tests need to utilize the transaction templates that are contained in `transactions/`.

## License 

The works in these folders are under the [Unlicense](https://github.com/dapperlabs/flow-core-contracts/blob/master/LICENSE):

- [src/contracts](https://github.com/dapperlabs/flow-core-contracts/tree/master/src/contracts)


