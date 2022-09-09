import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Transaction that allows ExecutionNodeVersionAdmin to delete the latest
/// version boundary mapping defined in the version table

transaction() {

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
    self.ExecutionNodeVersionBeaconAdminRef.deleteLatestVersionBoundary()
  }

}
