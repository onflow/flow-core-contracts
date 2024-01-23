import "BurnableTest"
import "Burner"

transaction(allowDestroy: Bool, dictType: Type) {
    prepare(acct: AuthAccount) {
        let before = BurnableTest.totalBurned

        let r <- BurnableTest.createSafe(allowDestroy: allowDestroy)
        if dictType as? Number != nil {
            let d: @{Number: AnyResource} <- {1: <-r}
            Burner.burn(<-d)
        } else if dictType as? String != nil {
            let d: @{String: AnyResource} <- {"a": <-r}
            Burner.burn(<-d)
        } else if dictType as? Path != nil {
            let d: @{Path: AnyResource} <- {/public/foo: <-r}
            Burner.burn(<-d)
        } else if dictType as? Address != nil {
            let d: @{Address: AnyResource} <- {Address(0x1): <-r}
            Burner.burn(<-d)
        } else if dictType as? Character != nil {
            let d: @{Character: AnyResource} <- {"c": <-r}
            Burner.burn(<-d)
        } else {
            let d: @{Type: AnyResource} <- {Type<Burner>(): <-r}
            Burner.burn(<-d)
        }

        if allowDestroy {
            assert(before + 1 == BurnableTest.totalBurned, message: "totalBurned was lower than expected")
        } else {
            assert(before == BurnableTest.totalBurned, message: "totalBurned value changed unexpectedly")
        }
    }
}
