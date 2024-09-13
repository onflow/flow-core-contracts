import Test
import BlockchainHelpers
import "FlowDKG"

// Account 7 is where new contracts are deployed by default
access(all) let admin = Test.getAccount(0x0000000000000007)

access(all)
fun setup() {
    let err = Test.deployContract(
        name: "FlowDKG",
        path: "../contracts/epochs/FlowDKG.cdc",
        arguments: []
    )
    Test.expect(err, Test.beNil())
}

///
/// FIXTURES
///

access(all) fun hexStringFixture(n: Int): String {
    let bytes: [UInt8] = []
    for i in InclusiveRange(1, n) {
        bytes.append(revertibleRandom<UInt8>())
    }
    let hex: String = String.encodeHex(bytes)
    return hex
}

access(all) fun pubKeyFixture(): String {
    return hexStringFixture(n: 96) // 96 bytes
}

access(all) fun nodeIDFixture(): String {
    return hexStringFixture(n: 32) // 32 bytes
}

access(all) fun pubKeysFixture(n: Int): [String] {
    let keys: [String] = []
    for i in InclusiveRange(1, n) {
        keys.append(pubKeyFixture())
    }
    return keys
}

access(all) fun nodeIDsFixture(n: Int): [String] {
    let ids: [String] = []
    for i in InclusiveRange(1, n) {
        ids.append(pubKeyFixture())
    }
    return ids
}

access(all) fun idMappingFixture(n: Int): {String: Int} {
    let nodeIDs = nodeIDsFixture(n: n)
    let map: {String: Int} = {}
    for i in InclusiveRange(0, n-1) {
        map[nodeIDs[i]] = i
    }
    return map
}

///
/// ResultSubmission Tests
///


/*
TODO tests:
- instantiation
 */

access(all)
fun testResultSubmissionInit_InvalidGroupKeyLength() {
    let groupKey = pubKeyFixture().concat(hexStringFixture(n: 1))
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeysFixture(n: 3), idMapping: idMappingFixture(n: 3))
    }, errorMessageSubstring: "invalid group key length")
}

access(all)
fun testResultSubmissionInit_InvalidParticipantKeyLength() {
    let pubKeys = pubKeysFixture(n: 3)
    pubKeys[2] = pubKeys[2].concat(hexStringFixture(n: 1))
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeys, idMapping: idMappingFixture(n: 3))
    }, errorMessageSubstring: "invalid participant key length")
}

access(all)
fun testResultSubmissionInit_InvalidIDMappingLength() {
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeysFixture(n: 3), idMapping: idMappingFixture(n: 4))
    }, errorMessageSubstring: "invalid id mapping length")
}

access(all)
fun testResultSubmissionInit_NilKeys() {
    let sub = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: [nil, nil, nil], idMapping: idMappingFixture(n: 3))
}

access(all)
fun testResultSubmissionEquals() {
    let groupKey = pubKeyFixture()
    let pubKeys  = pubKeysFixture(n: 10)
    let idMapping = idMappingFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    Test.assert(sub1.equals(sub2))
}

access(all)
fun testResultSubmissionEquals_differentGroupKey() {
    let pubKeys  = pubKeysFixture(n: 10)
    let idMapping = idMappingFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeys, idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeys, idMapping: idMapping)
    Test.assert(!sub1.equals(sub2))
}

access(all)
fun testResultSubmissionEquals_differentPubKeys() {
    let groupKey = pubKeyFixture()
    let idMapping = idMappingFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeysFixture(n: 10), idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeysFixture(n: 10), idMapping: idMapping)
    Test.assert(!sub1.equals(sub2))
}

access(all)
fun testResultSubmissionEquals_differentPubKeysOrder() {
    let groupKey = pubKeyFixture()
    let pubKeys  = pubKeysFixture(n: 10)
    let idMapping = idMappingFixture(n: 10)

    let reorderedPubKeys = pubKeys.reverse()

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: reorderedPubKeys, idMapping: idMapping)
    Test.assert(!sub1.equals(sub2))
}


access(all)
fun testResultSubmissionEquals_differentIDMapping() {
    let groupKey = pubKeyFixture()
    let pubKeys  = pubKeysFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMappingFixture(n: 10))
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMappingFixture(n: 10))
    Test.assert(!sub1.equals(sub2))
}

access(all)
fun testResultSubmissionEquals_differentIDMappingValues() {
    let groupKey = pubKeyFixture()
    let pubKeys  = pubKeysFixture(n: 10)
    let idMapping = idMappingFixture(n: 10)

    let idMappingWithShuffledValues = idMapping
    let nodeID1 = idMappingWithShuffledValues.keys[0]
    let nodeID2 = idMappingWithShuffledValues.keys[1]
    idMappingWithShuffledValues[idMapping.keys[0]] = idMapping[idMapping.keys[1]]
    idMappingWithShuffledValues[idMapping.keys[1]] = idMapping[idMapping.keys[0]]

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMappingWithShuffledValues)
    Test.assert(!sub1.equals(sub2))
}

///
/// SubmissionTracker Tests
///

/*
- add first submission
- add distinct submissions
- add same submissions
- add mix of distinct and same submissions

- test upgrade path (submission tracker is not in storage)
 */

access(all)
fun testSubmissionTracker() {
    let tracker = FlowDKG.SubmissionTracker()
    Test.assert(true)
}

