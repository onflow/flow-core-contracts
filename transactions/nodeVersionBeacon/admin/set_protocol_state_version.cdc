import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that allows NodeVersionAdmin to specify a new protocol state version.
/// The new version will become active at view `activeView`.
/// If `activeView` is in the past, or 0, it will become active immediately.

transaction(newProtocolVersion: UInt64, activeView: UInt64) {

  let adminRef: &NodeVersionBeacon.Admin

  prepare(acct: AuthAccount) {
    // Borrow a reference to the NodeVersionAdmin implementing resource
    self.adminRef = acct.borrow<&NodeVersionBeacon.Admin>(from: NodeVersionBeacon.AdminStoragePath)
      ?? panic("Couldn't borrow NodeVersionBeacon.Admin Resource")
  }

  execute {
    self.adminRef.setPendingProtocolStateVersionUpgrade(newProtocolVersion: newProtocolVersion, activeView: activeView)
  }

//   post {
//     NodeVersionBeacon.peekPendingProtocolStateVersionUpgrade().version! == newProtocolVersion : "version not updated"
//     NodeVersionBeacon.peekPendingProtocolStateVersionUpgrade().activeView! == activeView : "active view not updated"
//   }
}
