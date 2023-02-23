import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Gets the current version defined in the versionTable
/// as a String or nil if none is defined
pub fun main(): String? {
    if let version = NodeVersionBeacon.getCurrentNodeVersion() {
        return version.toString()
    } else {
        return nil
    }
}
