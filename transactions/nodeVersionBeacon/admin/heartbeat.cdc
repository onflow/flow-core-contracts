import "NodeVersionBeacon"

// Calls the method that emits the table with the incoming versions
transaction() {

    let NodeVersionBeaconHeartbeatRef: &NodeVersionBeacon.Heartbeat

    prepare(acct: auth(BorrowValue) &Account) {
        // Borrow a reference to the NodeVersionAdmin resource
        self.NodeVersionBeaconHeartbeatRef = acct.storage.borrow<&NodeVersionBeacon.Heartbeat>
          (from: NodeVersionBeacon.HeartbeatStoragePath)
          ?? panic("Couldn't borrow NodeVersionBeacon.Heartbeat Resource")
    }   
    execute {
        self.NodeVersionBeaconHeartbeatRef.heartbeat()
    }
}