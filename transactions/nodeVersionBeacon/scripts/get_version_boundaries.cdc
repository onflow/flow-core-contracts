import NodeVersionBeacon from "NodeVersionBeacon"

/// Returns the versionBoundaries page for the given page and perPage.
access(all) fun main(page: Int, perPage: Int): NodeVersionBeacon.VersionBoundaryPage {
    return NodeVersionBeacon.getVersionBoundariesPage(page: page, perPage: perPage)
}