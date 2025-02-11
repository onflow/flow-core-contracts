import "NodeVersionBeacon"

/// Gets the next sequence number for the table updated event
access(all) fun main(): UInt64 {
    return NodeVersionBeacon.getNextVersionBeaconSequence()
}