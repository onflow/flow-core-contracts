import ExecutionNodeVersionBeacon from 0xEXECUTIONNODEVERSIONBEACONADDRESS

/// Transaction that allows ExecutionNodeVersionAdmin to add a new version to the
/// version table defining a version boundary at the targetBlockHeight

transaction(
  newMajor: UInt8,
  newMinor: UInt8,
  newPatch: UInt8,
  newPreRelease: String?,
  isBackwardsCompatible: Bool,
  targetBlockHeight: UInt64
) {

  let ExecutionNodeVersionBeaconAdminRef: &ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin
  let newVersion: ExecutionNodeVersionBeacon.Semver

  prepare(acct: AuthAccount) {
    // Create the new version from the passed parameters
    self.newVersion = ExecutionNodeVersionBeacon.Semver(
      major: newMajor, minor: newMinor, patch: newPatch, preRelease: newPreRelease, isBackwardsCompatible: isBackwardsCompatible
    )

    // Borrow a reference to the ExecutionNodeVersionAdmin resource
    self.ExecutionNodeVersionBeaconAdminRef = acct.borrow<&ExecutionNodeVersionBeacon.ExecutionNodeVersionAdmin>
      (from: ExecutionNodeVersionBeacon.ExecutionNodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow ExecutionNodeVersionBeaconAdmin Resource")
  }

  execute {
    // Add the new version to the version table
    self.ExecutionNodeVersionBeaconAdminRef.addVersionBoundaryToTable(targetBlockHeight: targetBlockHeight, newVersion: self.newVersion)
  }

  post{
    ExecutionNodeVersionBeacon.getVersionTable()[targetBlockHeight]!.strictEqualTo(self.newVersion) : "New version was not added to the versionTable"
  }
}
