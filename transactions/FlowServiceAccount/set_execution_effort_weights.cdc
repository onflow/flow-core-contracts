// This transactions sets new execution effort weights
// The maximum execution effort limit for transactions is always 99999.
// The weight names/ids can be seen here:
// 
// - [Cadence ComputationKind](https://github.com/onflow/cadence/blob/6075ef48c7c2a061d27e36b095ae7ec5e2045ca7/runtime/common/computationkind.go#L30)
// - [FVM ComputationKind](https://github.com/onflow/flow-go/blob/1df43de85c5b75618511a8fe99e9998ab2e4cd59/fvm/meter/meter.go#L9)
//
// - the internal precision of the execution effort meter is 2^16, which means 2^16 is equal to 1 out of the total 99999 execution effort available to a transaction.
//
// The default weights are:
//
// - ComputationKindLoop: 1
// - ComputationKindStatement: 1 
// - ComputationKindFunctionInvocation: 1
//
// or in parameter form:
//
// ```json
// [
//   {
//     "type": "Dictionary",
//     "value": [
//       {
//         "key": { "type": "UInt64", "value": "1001" },
//         "value": { "type": "UInt64", "value": "65536" }
//       },
//       {
//         "key": { "type": "UInt64", "value": "1002" },
//         "value": { "type": "UInt64", "value": "65536" }
//       },
//       {
//         "key": { "type": "UInt64", "value": "1003" },
//         "value": { "type": "UInt64", "value": "65536" }
//       }
//     ]
//   },
//   { "type": "Path", "value": { "domain": "storage", "identifier": "executionEffortWeights" } }
// ]
// ```
transaction(newWeights: {UInt64: UInt64}) {
    prepare(signer: auth(Storage) &Account) {
        signer.storage.load<{UInt64: UInt64}>(from: /storage/executionEffortWeights)
        signer.storage.save(newWeights, to: /storage/executionEffortWeights)
    }
}