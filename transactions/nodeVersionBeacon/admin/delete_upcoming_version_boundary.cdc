import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that allows NodeVersionAdmin to delete the
/// version boundary mapping in the versionTable at the specified
/// block height parameter

transaction(blockHeightBoundaryToDelete: UInt64) {

  let NodeVersionBeaconAdminRef: &NodeVersionBeacon.NodeVersionAdmin

  prepare(acct: AuthAccount) {
    pre {
        NodeVersionBeacon.getVersionTable().length > 0 : "No boundary mapping exists to delete."
    }
    // Borrow a reference to the NodeVersionAdmin resource
    self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.NodeVersionAdmin>
      (from: NodeVersionBeacon.NodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
  }

  execute {
    // Delete the version from the version table at the specified block height boundary
    self.NodeVersionBeaconAdminRef.deleteUpcomingVersionBoundary(blockHeight: blockHeightBoundaryToDelete)
  }

}