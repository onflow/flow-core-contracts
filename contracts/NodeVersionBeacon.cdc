/// The NodeVersionBeacon contract holds the past and future protocol versions.
/// that should be used to execute/handle blocks at aa given block height.
/// 
/// The service account holds the NodeVersionBeacon.Heartbeat resource
/// which is responsible for emitting the VersionBeacon event. 
/// The event contains the current version and all the upcoming versions.
/// The event is emitted every time the version table is updated
/// or a version boundary is reached.
///
/// The NodeVersionBeacon.Admin resource is used to add new version boundaries
/// or change existing future version boundaries. Future version boundaries can only be
/// changed if they occur after the current block height + versionUpdateFreezePeriod.
/// This is to ensure that nodes have enough time to react to version table changes.
/// The versionUpdateFreezePeriod can also be changed by the admin resource, but only if
/// there are no upcoming version boundaries within the current versionUpdateFreezePeriod or 
/// the new versionUpdateFreezePeriod.
///
/// The contract itself can be used to query the current version and the next upcoming version.
pub contract NodeVersionBeacon {

    /// Struct representing software version as Semantic Version
    /// along with helper functions
    /// For reference, see https://semver.org/
    pub struct Semver {
        /// Components defining a semantic version
        pub let major: UInt8
        pub let minor: UInt8
        pub let patch: UInt8
        pub let preRelease: String?

        init(major: UInt8, minor: UInt8, patch: UInt8, preRelease: String?) {
            self.major = major
            self.minor = minor
            self.patch = patch
            self.preRelease = preRelease
        }

        /// Returns version in Semver format (e.g. v<major>.<minor>.<patch>-<preRelease>)
        /// as a String
        pub fun toString(): String {
            let semverCoreString = self.major.toString()
                 .concat(".")
                 .concat(
                     self.minor.toString()
                 ).concat(".")
                 .concat(
                     self.patch.toString()
                 )
            // Concat pre-release if it exists & return
            if self.preRelease != nil {
                return semverCoreString.concat("-").concat(self.preRelease!)
            }

            return semverCoreString
        }

        /* Custom Comparators */

        /// Returns true if Semver core is greater than
        /// passed Semver core and false otherwise
        pub fun coreGreaterThan(_ other: Semver): Bool {
            if (self.major != other.major) {
                return self.major > other.major
            }
            
            if (self.minor != other.minor) {
                return self.minor > other.minor
            }

            if (self.patch != other.patch) {
                return self.patch > other.patch
            } 

            return false
        }

        /// Returns true if Semver core is greater than or
        /// equal to passed Semver core and false otherwise
        pub fun coreGreaterThanOrEqualTo(_ other: Semver): Bool {
            return self.coreGreaterThan(other) || self.coreEqualTo(other)
        }

        /// Returns true if Semver core is less than
        /// passed Semver core and false otherwise
        pub fun coreLessThan(_ other: Semver): Bool {
            return !self.coreGreaterThanOrEqualTo(other)
        }

        /// Returns true if Semver core is less than or
        /// equal to passed Semver core and false otherwise
        pub fun coreLessThanOrEqualTo(_ other: Semver): Bool {
            return !self.coreGreaterThan(other)
        }

        /// Returns true if Semver is equal to passed
        /// Semver core and false otherwise
        pub fun coreEqualTo(_ other: Semver): Bool {
            return self.major == other.major && self.minor == other.minor && self.patch == other.patch
        }

        /// Returns true if Semver is *exactly* equal to passed
        /// Semver and false otherwise
        pub fun strictEqualTo(_ other: Semver): Bool {
            return self.coreEqualTo(other) && self.preRelease == other.preRelease
        }
    }

    /// Returns the v0.0.0 version.
    pub fun zeroSemver(): Semver {
        return Semver(major: 0, minor: 0, patch: 0, preRelease: nil)
    }

    /// Struct for emitting the current and incoming versions along with their block
    pub struct VersionBoundary {
        pub let blockHeight: UInt64
        pub let version: Semver

        init(blockHeight: UInt64, version: Semver){
            self.blockHeight = blockHeight
            self.version = version
        }
    }

    /// Returns the zero boundary. Used as a sentinel value 
    /// for versions before the version beacon contract.
    /// Simplifies edge case code.
    /// The zero boundary is at block height 0 and has version v0.0.0.
    /// It is always the first element in the versionBoundaryBlockList.
    pub fun zeroVersionBoundary(): VersionBoundary {
        let zeroVersion = self.zeroSemver()
        return VersionBoundary(
            blockHeight: 0, 
            version: zeroVersion,
        )
    }

    /// Event emitted when the version table is updated.
    /// It contains the current version and all the upcoming versions
    /// sorted by block height.
    /// The sequence increases by one each time an event is emitted. 
    /// It can be used to verify no events were missed.
    pub event VersionBeacon(
        versionBoundaries: [VersionBoundary],
        sequence: UInt64
    )

    /// Event emitted any time the version boundary freeze period is updated.
    /// freeze period is measured in blocks (from the current block).
    pub event NodeVersionBoundaryFreezePeriodChanged(freezePeriod: UInt64)

    /// Canonical storage path for the NodeVersionBeacon.Admin resource.
    pub let AdminStoragePath: StoragePath

    /// Canonical storage path for the NodeVersionBeacon.Heartbeat resource.
    pub let HeartbeatStoragePath: StoragePath

    /// Block height indexed version boundaries.
    access(contract) let versionBoundary: {UInt64: VersionBoundary}    
    
    /// Sorted Array containing version boundary block heights.
    access(contract) var versionBoundaryBlockList: [UInt64]

    /// Index in the versionBoundaryBlockList of the next upcoming version boundary,
    /// or nil if no upcoming version boundary.
    access(contract) var firstUpcomingBoundary: UInt64?
    
    /// versionUpdateFreezePeriod is the number of blocks (past the current one) for which version boundary 
    /// changes are not allowed. This is to ensure that nodes have enough time to react to 
    /// version table changes.
    access(contract) var versionBoundaryFreezePeriod: UInt64

    /// Boolean flag for keeping track if a VersionBeacon event needs to be emitted on next heartbeat.
    access(contract) var emitEventOnNextHeartbeat: Bool

    /// A counter that increases every time the Version beacon event is emitted.
    access(contract) var nextVersionBeaconEventSequence: UInt64

    /// Admin resource that manages version boundaries
    /// maintained in this contract.
    pub resource Admin {
        /// Adds or updates a version boundary.
        pub fun setVersionBoundary(versionBoundary: VersionBoundary) {
            pre {
                versionBoundary.blockHeight > getCurrentBlock().height + NodeVersionBeacon.versionBoundaryFreezePeriod
                    : "Cannot set/update a version boundary for past blocks or blocks in the near future."
            }
            // Set the flag to true so the event will be emitted next time emitChanges is called
            NodeVersionBeacon.emitEventOnNextHeartbeat = true

            let exists = NodeVersionBeacon.versionBoundary[versionBoundary.blockHeight] != nil
            NodeVersionBeacon.versionBoundary[versionBoundary.blockHeight] = versionBoundary

            if exists {
                // this was an update so nothing else needs to be done
                return
            } 

            // We have to insert the block height into the ordered list.
            // This is an inefficient algorithm, but it is not expected that the list of 
            // upcoming versions will be long.
            var i = NodeVersionBeacon.versionBoundaryBlockList.length
            while i > 1 && NodeVersionBeacon.versionBoundaryBlockList[i-1] > versionBoundary.blockHeight  {
                i = i - 1
            }
            NodeVersionBeacon.versionBoundaryBlockList.insert(at: i, versionBoundary.blockHeight)

            // no need to change the firstUpcomingBoundary unless it was nil
            // case 1: index points to a lower block height then the one inserted
            // => it should remain pointing at that index
            // case 2: index points to the entry that was replaced by this insert
            // => it should remain pointing at this new entry, since it is before the old one
            // case 3: index was pointing to an entry later than the insert FixedPoint
            // => this is illegal and cannot happen since there are entries with lower block heights.
            if NodeVersionBeacon.firstUpcomingBoundary == nil {
                NodeVersionBeacon.firstUpcomingBoundary = UInt64(NodeVersionBeacon.versionBoundaryBlockList.length - 1)
            }
        }

        /// Deletes an upcoming version boundary.
        pub fun deleteVersionBoundary(blockHeight: UInt64) {
            pre {
                blockHeight > getCurrentBlock().height + NodeVersionBeacon.versionBoundaryFreezePeriod
                    : "Cannot delete a version for past blocks or blocks in the near future."
                NodeVersionBeacon.versionBoundary.containsKey(blockHeight): "No boundary defined at that blockHeight."
            }
            // Set the flag to true so the event will be emitted next time emitChanges is called
            NodeVersionBeacon.emitEventOnNextHeartbeat = true

            // Remove the version mapping and upcomingBlockBoundaries
            NodeVersionBeacon.versionBoundary.remove(key: blockHeight)

            // We have to remove the block height from the ordered list.
            // This is an inefficient algorithm, but it is not expected that the list of 
            // upcoming versions will be long.
            var i = NodeVersionBeacon.versionBoundaryBlockList.length - 1
            while i > 0 && NodeVersionBeacon.versionBoundaryBlockList[i] > blockHeight  {
                i = i - 1
            }
            assert(NodeVersionBeacon.versionBoundaryBlockList[i] == blockHeight,
             message: "version boundary exists in map, so it should also exist in the ordered list")

            NodeVersionBeacon.versionBoundaryBlockList.remove(at: i)

            // the index has to be fixed, but you cannot change records before the index
            // so the only case to be addressed is that the index is pointing off the list,
            // because the list is now shorter.
            if NodeVersionBeacon.firstUpcomingBoundary != nil && 
                NodeVersionBeacon.firstUpcomingBoundary! >= UInt64(NodeVersionBeacon.versionBoundaryBlockList.length) {
                NodeVersionBeacon.firstUpcomingBoundary = nil
            }

        }

        /// Updates the number of blocks in which version boundaries are frozen.
        pub fun setVersionBoundaryFreezePeriod(newFreezePeriod: UInt64) {
            post {
                NodeVersionBeacon.versionBoundaryFreezePeriod == newFreezePeriod: "Update buffer was not properly set!"
            }

            // Get current block height.
            let currentBlockHeight = getCurrentBlock().height

            // No boundaries defined beyond current block, safe to make changes
            if NodeVersionBeacon.firstUpcomingBoundary == nil {
                NodeVersionBeacon.versionBoundaryFreezePeriod = newFreezePeriod
                return
            } 
            
            let nextBlockBoundary = NodeVersionBeacon.versionBoundaryBlockList[NodeVersionBeacon.firstUpcomingBoundary!]

            // Ensure that the we're not currently within the old or new freeze period
            // of the next block height boundary
            assert(
                currentBlockHeight + NodeVersionBeacon.versionBoundaryFreezePeriod < nextBlockBoundary &&
                currentBlockHeight + newFreezePeriod < nextBlockBoundary,
                message: "Updating buffer now breaks version boundary update expectations. Try updating buffer after next version boundary."
            )

            NodeVersionBeacon.versionBoundaryFreezePeriod = newFreezePeriod
            
            emit NodeVersionBoundaryFreezePeriodChanged(freezePeriod: newFreezePeriod)
        }
    }

    /// Heartbeat resource that emits the version beacon event and keeps track of upcoming versions.
    /// This resource should always be held only by the service account,
    /// because the service account should be the only one emitting the event, 
    /// and only during the system transaction
    pub resource Heartbeat {
        // heartbeat is called during the system transaction every block.
        pub fun heartbeat() {
            self.checkFirstUpcomingBoundary()

            if (!NodeVersionBeacon.emitEventOnNextHeartbeat) {
                return
            }
            NodeVersionBeacon.emitEventOnNextHeartbeat = false

            self.emitVersionBeaconEvent(versionBoundaries: NodeVersionBeacon.getCurrentVersionBoundaries())
        }

        access(self) fun emitVersionBeaconEvent(versionBoundaries : [VersionBoundary]) {
            
            emit VersionBeacon(versionBoundaries: versionBoundaries,
                sequence: NodeVersionBeacon.nextVersionBeaconEventSequence)
            // After emitting the event increase the event sequence number and set the flag to false
            // so the event won't be emitted on the next block if there isn't any changes to the table
            NodeVersionBeacon.nextVersionBeaconEventSequence = NodeVersionBeacon.nextVersionBeaconEventSequence + 1
        
        }

        /// Check if the index pointing to the next version boundary needs to be moved.
        access(self) fun checkFirstUpcomingBoundary() {
            if NodeVersionBeacon.firstUpcomingBoundary == nil {
                return
            }

            let currentBlockHeight = getCurrentBlock().height
            var boundaryIndex =  NodeVersionBeacon.firstUpcomingBoundary!
            while boundaryIndex < UInt64(NodeVersionBeacon.versionBoundaryBlockList.length) 
              && NodeVersionBeacon.versionBoundaryBlockList[boundaryIndex] <= currentBlockHeight {
                boundaryIndex = boundaryIndex + 1
            }

            if boundaryIndex == NodeVersionBeacon.firstUpcomingBoundary! {
                // no change
                return
            }

            if boundaryIndex >= UInt64(NodeVersionBeacon.versionBoundaryBlockList.length) {
                NodeVersionBeacon.firstUpcomingBoundary = nil
            } else {
                NodeVersionBeacon.firstUpcomingBoundary = boundaryIndex 
            }

            // If we passed a boundary re-emit the VersionBeacon event
            NodeVersionBeacon.emitEventOnNextHeartbeat = true
        }
    }

    /// getCurrentVersionBoundaries returns the current version boundaries.
    /// this is the same list as the one emitted by the VersionBeacon event.
    pub fun getCurrentVersionBoundaries(): [VersionBoundary] {
            let tableUpdates: [VersionBoundary] = []

            if NodeVersionBeacon.firstUpcomingBoundary == nil {
                // no future boundaries. Just return the last one.
                // this is safe, there is at least one record in the versionBoundaryBlockList
                tableUpdates.append(NodeVersionBeacon.versionBoundary[
                    NodeVersionBeacon.versionBoundaryBlockList[NodeVersionBeacon.versionBoundaryBlockList.length - 1]
                ]!)
                return tableUpdates
            }

            // -1 to include the version the node should currently be on
            var start = (NodeVersionBeacon.firstUpcomingBoundary ?? UInt64(NodeVersionBeacon.versionBoundaryBlockList.length)) - 1
            let end = UInt64(NodeVersionBeacon.versionBoundaryBlockList.length)

            if start < 0 {
                // this is the case when the current index is at 0
                start = 0
            }

            var i = start

            while i < end {
                let block = NodeVersionBeacon.versionBoundaryBlockList[i]
                tableUpdates.append(NodeVersionBeacon.versionBoundary[block]!)
                i = i + 1
            }

            return tableUpdates
    }

    /// Returns the versionBoundaryFreezePeriod
    pub fun getVersionBoundaryFreezePeriod(): UInt64 {
        return NodeVersionBeacon.versionBoundaryFreezePeriod
    }

    /// Returns the sequence number of the next version beacon event
    /// This can be used to verify that no version beacon events were missed.
    pub fun getNextVersionBeaconSequence(): UInt64 {
        return self.nextVersionBeaconEventSequence
    }

    /// Function that returns the version that was defined at the most
    /// recent block height boundary. May return zero boundary.
    pub fun getCurrentVersionBoundary(): VersionBoundary {
        var current = 0 as UInt64

        // index is never 0 since version 0 is always in the past
        if let index = NodeVersionBeacon.firstUpcomingBoundary {
            assert(index > 0, message: "index should never be 0 since version 0 is always in the past")
            current = self.versionBoundaryBlockList[index-1]
        } else {
            current = UInt64(NodeVersionBeacon.versionBoundaryBlockList.length - 1)
        }

        let block = self.versionBoundaryBlockList[current]

        // Return the version mapped to the last historical block height boundary
        return self.versionBoundary[block]!
    }

    pub fun getNextVersionBoundary() : VersionBoundary? {
        if let index = NodeVersionBeacon.firstUpcomingBoundary {
            let block = self.versionBoundaryBlockList[index]
            return self.versionBoundary[block]
        } else {
            return nil
        }
    }

    /// Checks whether given version was compatible at the given historical block height
    pub fun getVersionBoundary(effectiveAtBlockHeight: UInt64): VersionBoundary {
        let block = self.searchForClosestHistoricalBlockBoundary(blockHeight: effectiveAtBlockHeight)
 
        return self.versionBoundary[block]!
    }

    pub struct VersionBoundaryPage {
        pub let page: Int
        pub let perPage: Int
        pub let totalLength: Int
        pub let values : [VersionBoundary]
    
        init(page: Int, perPage: Int, totalLength: Int, values: [VersionBoundary]) {
            self.page = page
            self.perPage = perPage
            self.totalLength = totalLength
            self.values = values
        }
        
    }

    /// Returns a page of version boundaries
    /// page is zero based
    /// results are sorted by block height
    pub fun getVersionBoundariesPage(page: Int, perPage: Int) : VersionBoundaryPage {
        pre {
            page >= 0: "page must be greater than or equal to 0"
            perPage > 0: "perPage must be greater than 0"
        }

        let totalLength = NodeVersionBeacon.versionBoundaryBlockList.length
        var startIndex = page * perPage
        if startIndex > totalLength {
            startIndex = totalLength
        }
        var endIndex = startIndex + perPage
        if endIndex > totalLength {
            endIndex = totalLength
        }
        let values: [VersionBoundary] = []
        if startIndex == endIndex {
            return VersionBoundaryPage(page: page, perPage: perPage, totalLength: totalLength, values: values)
        }
        for block in self.versionBoundaryBlockList.slice(from: startIndex, upTo: endIndex) {
            values.append(NodeVersionBeacon.versionBoundary[block]!)
        }
        return VersionBoundaryPage(page: page, perPage: perPage, totalLength: totalLength, values: values)
    }


    /// Binary search algorithm to find closest value key in versionTable that is <= target value
    access(contract) fun searchForClosestHistoricalBlockBoundary(blockHeight: UInt64): UInt64 {
        // Return last block boundary if target is beyond
        let length = self.versionBoundaryBlockList.length
        if blockHeight >= self.versionBoundaryBlockList[length - 1] {
            return self.versionBoundaryBlockList[length - 1]
        }

        // Define search bounds
        var left = 0
        var right = length
        // Loop until search pointers cross
        while left < right {
            var mid = (left + right) / 2
            if self.versionBoundaryBlockList[mid] == blockHeight {
                return self.versionBoundaryBlockList[mid]
            }
            if blockHeight < self.versionBoundaryBlockList[mid] {
                if mid > 0 && blockHeight > self.versionBoundaryBlockList[mid -1] {
                    return self.versionBoundaryBlockList[mid - 1]
                }
                right = mid
            } else {
                if mid < (length - 1) && blockHeight < self.versionBoundaryBlockList[mid + 1] {
                    return self.versionBoundaryBlockList[mid]
                }
                left = mid + 1
            }
        }
        // Return zero version if nothing found
        return self.versionBoundaryBlockList[0]
    }

    init(versionUpdateFreezePeriod: UInt64) {
        self.AdminStoragePath = /storage/NodeVersionBeaconAdmin
        self.HeartbeatStoragePath = /storage/NodeVersionBeaconHeartbeat

        // insert a zero-th version to make the API simpler and more robust 
        let zero = NodeVersionBeacon.zeroVersionBoundary()
        
        self.versionBoundary = {zero.blockHeight:zero}
        self.versionBoundaryBlockList = [zero.blockHeight]
        self.versionBoundaryFreezePeriod = versionUpdateFreezePeriod
        self.firstUpcomingBoundary = nil
        self.nextVersionBeaconEventSequence = 0

        // emit the event on the first heartbeat to send the zero version
        self.emitEventOnNextHeartbeat = true

        self.account.save(<-create Admin(), to: self.AdminStoragePath)
        self.account.save(<-create Heartbeat(), to: self.HeartbeatStoragePath)
    }
}
 