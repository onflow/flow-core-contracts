import ExecutionNodeVersionBeacon from 0x02

/// Transaction that allows ExecutionNodeVersionAdmin to delete the
/// version boundary mapping in the versionTable at the specified
/// block height parameter

transaction(blockHeightBoundaryToDelete: UInt64) {

  let ExecutionNodeVersionBeaconAdminRef: &AnyResource{ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin}

  prepare(acct: AuthAccount) {
    pre{
        ExecutionNodeVersionBeacon.getVersionTable().length > 0 : "No boundary mapping exists to delete."
    }
    // Borrow a reference to the ExecutionNodeVersionAdmin implementing resource
    self.ExecutionNodeVersionBeaconAdminRef = acct.borrow<&AnyResource{ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin}>
      (from: ExecutionNodeVersionBeacon.ExecutionNodeVersionKeeperStoragePath)
      ?? panic("Couldn't borrow ExecutionNodeVersionBeaconAdmin Resource")
  }

  execute {
    // Add the new version to the version table
    self.ExecutionNodeVersionBeaconAdminRef.deleteUpcomingVersionBoundary(blockHeight: blockHeightBoundaryToDelete)
  }

}
