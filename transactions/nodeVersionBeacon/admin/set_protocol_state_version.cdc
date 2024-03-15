import NodeVersionBeacon from 0xNODEVERSIONBEACONADDRESS

/// Transaction that allows NodeVersionAdmin to specify a new protocol state version.
/// The new version will become active at view `activeView` if the service event
/// is processed and applied to the protocol state within a block `B` such that
/// `B.view + ∆ < activeView`, for a protocol-defined safety threshold ∆.
/// Service events not meeting this threshold are discarded.

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
}
