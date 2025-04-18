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

// Produce n random bytes and returns the corresponding hex-encoded representation.
// Output strings have length 2n.
access(all) fun hexStringFixture(n: Int): String {
    let bytes: [UInt8] = []
    for i in InclusiveRange(1, n) {
        bytes.append(revertibleRandom<UInt8>())
    }
    let hex: String = String.encodeHex(bytes)
    return hex
}

access(all) fun pubKeyFixture(): String {
    return hexStringFixture(n: 96)
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
        ids.append(nodeIDFixture())
    }
    return ids
}

// Returns a node ID -> DKG index mapping (the idMapping field of ResultSubmission)
access(all) fun idMappingFixture(n: Int): {String: Int} {
    let nodeIDs = nodeIDsFixture(n: n)
    return idMappingFixtureWithNodeIDs(nodeIDs: nodeIDs)
}

access(all) fun idMappingFixtureWithNodeIDs(nodeIDs: [String]): {String: Int} {
    let map: {String: Int} = {}
    for i in InclusiveRange(0, nodeIDs.length-1) {
        map[nodeIDs[i]] = i
    }
    return map
}

access(all) fun resultSubmissionFixture(n: Int): FlowDKG.ResultSubmission {
    return FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeysFixture(n: n), idMapping: idMappingFixture(n: n))
}

access(all) fun resultSubmissionFixtureWithNodeIDs(nodeIDs: [String]): FlowDKG.ResultSubmission {
    return FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeysFixture(n: nodeIDs.length), idMapping: idMappingFixtureWithNodeIDs(nodeIDs: nodeIDs))
}

///
/// ResultSubmission Tests
///

// Instantiation should fail with invalid group key length.
access(all) fun testResultSubmissionInit_InvalidGroupKeyLength() {
    let groupKey = pubKeyFixture().concat(hexStringFixture(n: 1))
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeysFixture(n: 3), idMapping: idMappingFixture(n: 3))
    }, errorMessageSubstring: "invalid group key")
}

// Instantiation should fail with invalid participant key length.
access(all) fun testResultSubmissionInit_InvalidParticipantKeyLength() {
    let pubKeys = pubKeysFixture(n: 3)
    pubKeys[2] = pubKeys[2].concat(hexStringFixture(n: 1))
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeys, idMapping: idMappingFixture(n: 3))
    }, errorMessageSubstring: "invalid participant key")
}

// Instantiation should fail with invalid ID mapping length.
access(all) fun testResultSubmissionInit_InvalidIDMappingLength() {
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeysFixture(n: 3), idMapping: idMappingFixture(n: 4))
    }, errorMessageSubstring: "invalid ID mapping")
}

// Nil fields are allowed only when all fields are nil.
access(all) fun testResultSubmissionInit_EmptySubmission() {
    let sub = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: nil, idMapping: nil)

    // non-nil group key
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: nil, idMapping: nil)
    }, errorMessageSubstring: "empty submission invariant")

    // non-nil participant keys
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: pubKeysFixture(n: 3), idMapping: nil)
    }, errorMessageSubstring: "empty submission invariant")

    // non-nil id mapping
    Test.expectFailure(fun(): Void {
        let sub = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: nil, idMapping: idMappingFixture(n: 3))
    }, errorMessageSubstring: "empty submission invariant")
}

access(all) fun testResultSubmissionEquals() {
    let groupKey = pubKeyFixture()
    let pubKeys  = pubKeysFixture(n: 10)
    let idMapping = idMappingFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    Test.assert(sub1.equals(sub2))
}

access(all) fun testResultSubmissionEquals_Empty() {
    // Two empty submissions should be considered equal (there is exactly one representation for empty submission)
    let empty1 = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: nil, idMapping: nil)
    let empty2 = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: nil, idMapping: nil)
    Test.assert(empty1.equals(empty2))

    // An empty submission should not be considered equal to any non-empty submission
    let nonempty = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeysFixture(n: 10), idMapping: idMappingFixture(n: 10))
    Test.assert(!empty1.equals(nonempty))
}

access(all) fun testResultSubmissionEquals_differentGroupKey() {
    let pubKeys  = pubKeysFixture(n: 10)
    let idMapping = idMappingFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeys, idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: pubKeyFixture(), pubKeys: pubKeys, idMapping: idMapping)
    Test.assert(!sub1.equals(sub2))
}

access(all) fun testResultSubmissionEquals_differentPubKeys() {
    let groupKey = pubKeyFixture()
    let idMapping = idMappingFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeysFixture(n: 10), idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeysFixture(n: 10), idMapping: idMapping)
    Test.assert(!sub1.equals(sub2))
}

// The same participant public keys in a different order should fail equality check.
access(all) fun testResultSubmissionEquals_differentPubKeysOrder() {
    let groupKey = pubKeyFixture()
    let pubKeys  = pubKeysFixture(n: 10)
    let idMapping = idMappingFixture(n: 10)

    let reorderedPubKeys = pubKeys.reverse()

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMapping)
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: reorderedPubKeys, idMapping: idMapping)
    Test.assert(!sub1.equals(sub2))
}


access(all) fun testResultSubmissionEquals_differentIDMapping() {
    let groupKey = pubKeyFixture()
    let pubKeys  = pubKeysFixture(n: 10)

    let sub1 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMappingFixture(n: 10))
    let sub2 = FlowDKG.ResultSubmission(groupPubKey: groupKey, pubKeys: pubKeys, idMapping: idMappingFixture(n: 10))
    Test.assert(!sub1.equals(sub2))
}

// An ID mapping with the same keys (node IDs) but different values should fail equality check.
access(all) fun testResultSubmissionEquals_differentIDMappingValues() {
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

// Should have non-nil empty fields after initialization.
access(all) fun testSubmissionTracker_init() {
    let tracker = FlowDKG.SubmissionTracker()
    Test.assertEqual(0, tracker.authorized.length)
    Test.assertEqual(0, tracker.uniques.length)
    Test.assertEqual(0, tracker.byNodeID.length)
    Test.assertEqual(0, tracker.counts.length)
}

// Authorized list should be populated after reset
access(all) fun testSubmissionTracker_reset() {
    let tracker = FlowDKG.SubmissionTracker()
    let nodeIDs = nodeIDsFixture(n: 10)
    tracker.reset(nodeIDs: nodeIDs)
    Test.assertEqual(0, tracker.uniques.length)
    Test.assertEqual(0, tracker.byNodeID.length)
    Test.assertEqual(0, tracker.counts.length)

    Test.assertEqual(nodeIDs.length, tracker.authorized.length)
    for nodeID in nodeIDs {
        Test.assert(tracker.authorized[nodeID]!)
    }
}

access(all) fun testSubmissionTracker_addSubmission() {
    let tracker = FlowDKG.SubmissionTracker()
    let nodeIDs = nodeIDsFixture(n: 10)
    tracker.reset(nodeIDs: nodeIDs)

    let submittor = nodeIDs[0]
    let submission = resultSubmissionFixtureWithNodeIDs(nodeIDs: nodeIDs)
    tracker.addSubmission(nodeID: submittor, submission: submission)
    Test.assertEqual(tracker.byNodeID, {submittor: 0})
    Test.assertEqual(tracker.counts, {0: 1} as {Int: UInt64})
    Test.assertEqual(tracker.uniques, [submission])
}

// One node submitting more than one result should cause a panic
access(all) fun testSubmissionTracker_addSubmissionAlreadySubmitted() {
    let tracker = FlowDKG.SubmissionTracker()
    let nodeIDs = nodeIDsFixture(n: 10)
    tracker.reset(nodeIDs: nodeIDs)

    let submittor = nodeIDs[0]
    let submission = resultSubmissionFixtureWithNodeIDs(nodeIDs: nodeIDs)
    tracker.addSubmission(nodeID: submittor, submission: submission)

    // Resubmit the same result
    Test.expectFailure(fun(): Void {
        tracker.addSubmission(nodeID: submittor, submission: submission)
    }, errorMessageSubstring: "may only submit once and has already submitted")

    // Submit a different result
        Test.expectFailure(fun(): Void {
        tracker.addSubmission(nodeID: submittor, submission: resultSubmissionFixtureWithNodeIDs(nodeIDs: nodeIDs))
    }, errorMessageSubstring: "may only submit once and has already submitted")
}

// An unauthorized node attempting to submit should panic
access(all) fun testSubmissionTracker_addSubmissionUnauthorized() {
    let tracker = FlowDKG.SubmissionTracker()
    let nodeIDs = nodeIDsFixture(n: 10)
    tracker.reset(nodeIDs: nodeIDs)

    let unauthorizedSubmittor = nodeIDFixture()
    Test.expectFailure(fun(): Void {
        let submission = resultSubmissionFixtureWithNodeIDs(nodeIDs: nodeIDs)
        tracker.addSubmission(nodeID: unauthorizedSubmittor, submission: submission)
    }, errorMessageSubstring: "not authorized for this DKG instance")
}

access(all) fun testSubmissionTracker_submissionExceedsThreshold() {
    let tracker = FlowDKG.SubmissionTracker()
    let nodeIDs = nodeIDsFixture(n: 10)
    tracker.reset(nodeIDs: nodeIDs)
    let threshold: UInt64 = 4

    // Initially, should return nil
    Test.assertEqual(nil, tracker.submissionExceedsThreshold(threshold))

    let sub1 = resultSubmissionFixtureWithNodeIDs(nodeIDs: nodeIDs)
    let sub2 = resultSubmissionFixtureWithNodeIDs(nodeIDs: nodeIDs)

    // After inserting up to 4 submissions matching sub1, should return nil
    for nodeID in nodeIDs.slice(from: 0, upTo: 4) {
        tracker.addSubmission(nodeID: nodeID, submission: sub1)
        Test.assertEqual(nil, tracker.submissionExceedsThreshold(threshold))
    }

    // After inserting up to 4 submissions matching sub2, should still return nil
    for nodeID in nodeIDs.slice(from: 4, upTo: 8) {
        tracker.addSubmission(nodeID: nodeID, submission: sub2)
        Test.assertEqual(nil, tracker.submissionExceedsThreshold(threshold))
    }

    // After inserting the 5th matching submission (threshold+1), should return the winning submission
    tracker.addSubmission(nodeID: nodeIDs[8], submission: sub1)
    Test.assertEqual(sub1, tracker.submissionExceedsThreshold(threshold)!)
}

// Empty submissions should not count toward DKG completion
access(all) fun testSubmissionTracker_submissionExceedsThresholdEmpty() {
    let tracker = FlowDKG.SubmissionTracker()
    let nodeIDs = nodeIDsFixture(n: 10)
    tracker.reset(nodeIDs: nodeIDs)
    let threshold: UInt64 = 4

    // Initially, should return nil
    Test.assertEqual(nil, tracker.submissionExceedsThreshold(threshold))

    let emptySubmission = FlowDKG.ResultSubmission(groupPubKey: nil, pubKeys: nil, idMapping: nil)

    // After inserting up to 4 empty submissions, should return nil
    for nodeID in nodeIDs.slice(from: 0, upTo: 4) {
        tracker.addSubmission(nodeID: nodeID, submission: emptySubmission)
        Test.assertEqual(nil, tracker.submissionExceedsThreshold(threshold))
    }

    // After inserting the 5th empty submission (threshold+1), should still return nil
    // Empty submissions are excluded from considering DKG completion, as they indicate individual failures.
    tracker.addSubmission(nodeID: nodeIDs[4], submission: emptySubmission)
    Test.assertEqual(nil, tracker.submissionExceedsThreshold(threshold))
}
