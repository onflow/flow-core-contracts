import "FlowCallbackScheduler"

access(all) contract TestFlowCallbackQueue {
    access(all) var allExpectedIDs: [[UInt64]]
    access(all) var index: Int

    init(expectedIDs: [[UInt64]]) {
        self.allExpectedIDs = expectedIDs
        self.index = 0
    }

    access(all) fun assertPendingQueue(actualIDs: [UInt64]) {
        let expectedIDs = self.allExpectedIDs[self.index]
        self.index = self.index + 1

        var actualIDsString = ""
        for id in actualIDs {
            actualIDsString = "\(actualIDsString) \(id)"
        }

        assert(actualIDs.length == expectedIDs.length, message: "Invalid number of pending IDs. Expected: \(expectedIDs.length), Got: \(actualIDs.length), Actual IDs: \(actualIDsString)")
        for id in expectedIDs {
            assert(actualIDs.contains(id), message: "Invalid ID: \(id) not found in pending IDs")
        }
    }
}