import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that allows NodeVersionAdmin to add a new version to the
/// version table defining a version boundary at the targetBlockHeight

transaction(
  newMajor: UInt8,
  newMinor: UInt8,
  newPatch: UInt8,
  newPreRelease: String?,
  isBackwardsCompatible: Bool,
  targetBlockHeight: UInt64
) {

  let NodeVersionBeaconAdminRef: &NodeVersionBeacon.NodeVersionAdmin
  let newVersion: NodeVersionBeacon.Semver

  prepare(acct: AuthAccount) {
    // Create the new version from the passed parameters
    self.newVersion = NodeVersionBeacon.Semver(
      major: newMajor, minor: newMinor, patch: newPatch, preRelease: newPreRelease, isBackwardsCompatible: isBackwardsCompatible
    )

    // Borrow a reference to the NodeVersionAdmin resource
    self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.NodeVersionAdmin>
      (from: NodeVersionBeacon.NodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
  }

  execute {
    // Add the new version to the version table
    self.NodeVersionBeaconAdminRef.addVersionBoundaryToTable(targetBlockHeight: targetBlockHeight, newVersion: self.newVersion)
  }

  post{
    NodeVersionBeacon.getVersionTable()[targetBlockHeight]!.strictEqualTo(self.newVersion) : "New version was not added to the versionTable"
  }
}
