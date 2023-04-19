import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Gets the next sequence number for the table updated event
pub fun main(): UInt64 {
    return NodeVersionBeacon.getNextVersionBeaconSequence()
}