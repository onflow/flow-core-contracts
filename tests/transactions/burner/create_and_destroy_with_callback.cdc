import "BurnableTest"
import "Burner"

transaction(allowDestroy: Bool) {
    prepare(acct: AuthAccount) {
        let before = BurnableTest.totalBurned

        let r <- BurnableTest.createSafe(allowDestroy: allowDestroy)
        Burner.burn(<- r)

        if allowDestroy {
            assert(before + 1 == BurnableTest.totalBurned, message: "totalBurned was lower than expected")
        } else {
            assert(before == BurnableTest.totalBurned, message: "totalBurned value changed unexpectedly")
        }
    }
}
