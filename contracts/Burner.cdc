// Burner is a contract that can facilitate the destruction of any resource on flow.
//
// Contributors
// - Austin Kline - https://twitter.com/austin_flowty
// - Deniz Edincik - https://twitter.com/bluesign
// - Bastian Müller - https://twitter.com/turbolent
pub contract Burner {
    // When Crescendo (Cadence 1.0) is released, custom destructors will be removed from cadece.
    // Burnable is an interface meant to replace this lost feature, allowing anyone to add a callback
    // method to ensure they do not destroy something which is not meant to be, or to add logic based on destruction
    // such as tracking the supply of an NFT Collection
    //
    // NOTE: The only way to see benefit from this interface is to call the burnCallback method yourself,
    // or to always use the burn method in this contract. Anyone who owns a resource can always elect **not**
    // to destroy a resource this way
    pub resource interface Burnable {
        pub fun burnCallback()
    }

    // burn is a global method which will destroy any resource it is given.
    // If the provided resource implements the Burnable interface, it will call the burnCallback
    // method and then destroy afterwards.
    pub fun burn(_ r: @AnyResource) {
        if let s <- r as? @{Burnable} {
            s.burnCallback()
            destroy s
        } else if let arr <- r as? @[AnyResource] {
            while arr.length > 0 {
                let item <- arr.removeFirst()
                self.burn(<-item)
            }
            destroy arr
        } else if let stringDict <- r as? @{String: AnyResource} {
            let keys = stringDict.keys
            while keys.length > 0 {
                let item <- stringDict.remove(key: keys.removeFirst())!
                self.burn(<-item)
            }
            destroy stringDict
        } else if let numDict <- r as? @{Number: AnyResource} {
            let keys = numDict.keys
            while keys.length > 0 {
                let item <- numDict.remove(key: keys.removeFirst())!
                self.burn(<-item)
            }
            destroy numDict
        } else if let typeDict <- r as? @{Type: AnyResource} {
            let keys = typeDict.keys
            while keys.length > 0 {
                let item <- typeDict.remove(key: keys.removeFirst())!
                self.burn(<-item)
            }
            destroy typeDict
        } else if let addressDict <- r as? @{Address: AnyResource} {
            let keys = addressDict.keys
            while keys.length > 0 {
                let item <- addressDict.remove(key: keys.removeFirst())!
                self.burn(<-item)
            }
            destroy addressDict
        } else if let pathDict <- r as? @{Path: AnyResource} {
            let keys = pathDict.keys
            while keys.length > 0 {
                let item <- pathDict.remove(key: keys.removeFirst())!
                self.burn(<-item)
            }
            destroy pathDict
        } else if let charDict <- r as? @{Character: AnyResource} {
            let keys = charDict.keys
            while keys.length > 0 {
                let item <- charDict.remove(key: keys.removeFirst())!
                self.burn(<-item)
            }
            destroy charDict
        } else {
            destroy r
        }
    }
}