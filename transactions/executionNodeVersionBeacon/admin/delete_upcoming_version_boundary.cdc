import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Transaction that allows ExecutionNodeVersionAdmin to delete the
/// version boundary mapping in the versionTable at the specified
/// block height parameter

transaction(blockHeightBoundaryToDelete: UInt64) {

  let ExecutionNodeVersionBeaconAdminRef: &ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin

  prepare(acct: AuthAccount) {
    pre {
        ExecutionNodeVersionBeacon.getVersionTable().length > 0 : "No boundary mapping exists to delete."
    }
    // Borrow a reference to the ExecutionNodeVersionAdmin resource
    self.ExecutionNodeVersionBeaconAdminRef = acct.borrow<&ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin>
      (from: ExecutionNodeVersionBeacon.ExecutionNodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow ExecutionNodeVersionBeaconAdmin Resource")
  }

  execute {
    // Delete the version from the version table at the specified block height boundary
    self.ExecutionNodeVersionBeaconAdminRef.deleteUpcomingVersionBoundary(blockHeight: blockHeightBoundaryToDelete)
  }

}