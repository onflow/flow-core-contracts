import NodeVersionBeacon from "NodeVersionBeacon"

/// Retrieves the next version boundary or nil
/// if there is no upcoming version boundary defined
access(all) fun main(): NodeVersionBeacon.VersionBoundary? {
    return NodeVersionBeacon.getNextVersionBoundary()
}
