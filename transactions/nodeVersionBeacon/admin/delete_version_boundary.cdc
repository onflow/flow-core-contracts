import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that allows NodeVersionAdmin to delete the
/// version boundary mapping in the versionTable at the specified
/// block height parameter

transaction(blockHeightBoundaryToDelete: UInt64) {

  let NodeVersionBeaconAdminRef: &NodeVersionBeacon.Admin

  prepare(acct: AuthAccount) {
    // Borrow a reference to the NodeVersionAdmin resource
    self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.Admin>
      (from: NodeVersionBeacon.AdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
  }

  execute {
    // Delete the version from the version table at the specified block height boundary
    self.NodeVersionBeaconAdminRef.deleteVersionBoundary(blockHeight: blockHeightBoundaryToDelete)
  }

}