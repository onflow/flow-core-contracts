import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS


/// TODO: This should modify the version table, but for testing its only call special function which emits service events

transaction(
  height: UInt64,
  newMajor: UInt8,
  newMinor: UInt8,
  newPatch: UInt8,
) {

  let NodeVersionBeaconAdminRef: &NodeVersionBeacon.NodeVersionAdmin
  let newVersion: NodeVersionBeacon.Semver

  prepare(acct: AuthAccount) {
    // Create the new version from the passed parameters
    self.newVersion = NodeVersionBeacon.Semver(
      major: newMajor, minor: newMinor, patch: newPatch, preRelease: nil, isBackwardsCompatible: true
    )

    // Borrow a reference to the NodeVersionAdmin resource
    self.NodeVersionBeaconAdminRef = acct.borrow<&NodeVersionBeacon.NodeVersionAdmin>
      (from: NodeVersionBeacon.NodeVersionAdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeaconAdmin Resource")
  }

  execute {
    // Add the new version to the version table
    self.NodeVersionBeaconAdminRef.testEmitEvent(height: height, version: self.newVersion)
  }

}
