import "BurnableTest"
import "Burner"

transaction {
    prepare(acct: AuthAccount) {
        let before = BurnableTest.totalBurned
        let r <- BurnableTest.createUnsafe()
        Burner.burn(<- r)

        assert(before == BurnableTest.totalBurned, message: "unexpected totalBurned value")
    }
}