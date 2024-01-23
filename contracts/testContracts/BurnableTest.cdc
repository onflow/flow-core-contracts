import "Burner"

pub contract BurnableTest {
    pub var totalBurned: UInt64

    pub resource WithCallback: Burner.Burnable {
        pub let allowDestroy: Bool

        pub fun burnCallback() {
            assert(self.allowDestroy, message: "allowDestroy must be set to true")
            BurnableTest.totalBurned = BurnableTest.totalBurned + 1
        }

        init(_ allowDestroy: Bool) {
            self.allowDestroy = allowDestroy
        }
    }

    pub resource WithoutCallback {}

    pub fun createSafe(allowDestroy: Bool): @WithCallback {
        return <- create WithCallback(allowDestroy)
    }

    pub fun createUnsafe(): @WithoutCallback {
        return <- create WithoutCallback()
    }

    init() {
        self.totalBurned = 0
    }
}