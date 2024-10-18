package static

import (
	_ "embed"
)

// RecoverNewEpochUnchecked is a transaction script that invokes recoverNewEpoch without any safety checks.
//
//go:embed "recover_new_epoch_unchecked.cdc"
var RecoverNewEpochUnchecked string
