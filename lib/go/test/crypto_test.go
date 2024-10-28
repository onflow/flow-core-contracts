package test

import (
	"context"
	"encoding/hex"
	"fmt"
	"testing"

	"github.com/onflow/cadence"
	jsoncdc "github.com/onflow/cadence/encoding/json"
	"github.com/onflow/flow-go-sdk"
	sdktemplates "github.com/onflow/flow-go-sdk/templates"
	"github.com/onflow/flow-go-sdk/test"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/onflow/flow-core-contracts/lib/go/contracts"
)

func TestCrypto(t *testing.T) {
	b, adapter := newBlockchain()

	accountKeys := test.AccountKeyGenerator()

	// Create new keys for the Crypto account and deploy
	cryptoAccountKey, _ := accountKeys.NewWithSigner()
	cryptoCode := contracts.Crypto()

	cryptoAddress, err := adapter.CreateAccount(
		context.Background(),
		[]*flow.AccountKey{cryptoAccountKey},
		[]sdktemplates.Contract{
			{
				Name:   "Crypto",
				Source: string(cryptoCode),
			},
		},
	)
	assert.NoError(t, err)

	script := []byte(fmt.Sprintf(
		`
          import Crypto from %s

          access(all)
          fun main(
            rawPublicKeys: [String],
            weights: [UFix64],
            domainSeparationTag: String,
            signatures: [String],
            toAddress: Address,
            fromAddress: Address,
            amount: UFix64
          ): Bool {
            let keyList = Crypto.KeyList()

            var i = 0
            for rawPublicKey in rawPublicKeys {
              keyList.add(
                PublicKey(
                  publicKey: rawPublicKey.decodeHex(),
                  signatureAlgorithm: SignatureAlgorithm.ECDSA_P256
                ),
                hashAlgorithm: HashAlgorithm.SHA3_256,
                weight: weights[i],
              )
              i = i + 1
            }

            let signatureSet: [Crypto.KeyListSignature] = []

            var j = 0
            for signature in signatures {
              signatureSet.append(
                Crypto.KeyListSignature(
                  keyIndex: j,
                  signature: signature.decodeHex()
                )
              )
              j = j + 1
            }

            // assemble the same message in cadence
            let message = toAddress.toBytes()
              .concat(fromAddress.toBytes())
              .concat(amount.toBigEndianBytes())

            return keyList.verify(
              signatureSet: signatureSet,
              signedData: message,
              domainSeparationTag: domainSeparationTag
            )
          }
        `,
		cryptoAddress.HexWithPrefix(),
	))

	// create the keys
	keyAlice, signerAlice := accountKeys.NewWithSigner()
	keyBob, signerBob := accountKeys.NewWithSigner()

	// create the message that will be signed
	addresses := test.AddressGenerator()

	toAddress := cadence.Address(addresses.New())
	fromAddress := cadence.Address(addresses.New())

	amount, err := cadence.NewUFix64("100.00")
	require.NoError(t, err)

	var message []byte
	message = append(message, toAddress.Bytes()...)
	message = append(message, fromAddress.Bytes()...)
	message = append(message, amount.ToBigEndianBytes()...)

	// sign the message with Alice and Bob
	signatureAlice, err := flow.SignUserMessage(signerAlice, message)
	require.NoError(t, err)

	signatureBob, err := flow.SignUserMessage(signerBob, message)
	require.NoError(t, err)

	publicKeys := cadence.NewArray([]cadence.Value{
		cadence.String(hex.EncodeToString(keyAlice.PublicKey.Encode())),
		cadence.String(hex.EncodeToString(keyBob.PublicKey.Encode())),
	})

	// each signature has half weight
	weightAlice, err := cadence.NewUFix64("0.5")
	require.NoError(t, err)

	weightBob, err := cadence.NewUFix64("0.5")
	require.NoError(t, err)

	weights := cadence.NewArray([]cadence.Value{
		weightAlice,
		weightBob,
	})

	signatures := cadence.NewArray([]cadence.Value{
		cadence.String(hex.EncodeToString(signatureAlice)),
		cadence.String(hex.EncodeToString(signatureBob)),
	})

	domainSeparationTag := cadence.String("FLOW-V0.0-user")

	arguments := []cadence.Value{
		publicKeys,
		weights,
		domainSeparationTag,
		signatures,
		toAddress,
		fromAddress,
		amount,
	}

	encodedArguments := make([][]byte, 0, len(arguments))
	for _, argument := range arguments {
		encodedArguments = append(encodedArguments, jsoncdc.MustEncode(argument))
	}

	result := executeScriptAndCheck(t, b, script, encodedArguments)

	assert.Equal(t,
		cadence.NewBool(true),
		result,
	)
}
