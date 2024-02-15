import NodeVersionBeacon from "NodeVersionBeacon"

/// Gets the current version defined in the contract's versionTable
access(all) fun main(): NodeVersionBeacon.Semver {
    return NodeVersionBeacon.getCurrentVersionBoundary().version
}
