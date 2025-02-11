import "NodeVersionBeacon"

/// Gets the current version defined in the versionTable
/// as a String.
access(all) fun main(): String {
    let boundary = NodeVersionBeacon.getCurrentVersionBoundary()
    return boundary.version.toString()
}
