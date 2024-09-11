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
    return String.encodeHex(bytes)
}

access(all) fun pubKeyFixture(): String {
    return hexStringFixture(n: 32)
}

access(all) fun nodeIDFixture(): String {
    return hexStringFixture(n: 32)
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

access(all)
fun testResultSubmissionEquals_empty() {
    let sub1 = FlowDKG.ResultSubmission(groupPubKey: "", pubKeys: [], idMapping: {})
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: "", pubKeys: [], idMapping: {})
    Test.assert(sub1.equals(sub2))

}

access(all)
fun testResultSubmissionEquals_nonEmpty() {
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

