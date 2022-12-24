import NodeVersionBeacon from "./../../../contracts/NodeVersionBeacon.cdc"

/// Gets the next sequence number for the table updated event
pub fun main(): UInt64 {
    return NodeVersionBeacon.getNextTableUpdatedSequence()
}
