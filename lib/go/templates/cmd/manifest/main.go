package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"

	"github.com/psiemens/sconfig"
	"github.com/spf13/cobra"

	"github.com/onflow/flow-core-contracts/lib/go/templates"
)

type Config struct {
	Network string `default:"mainnet" flag:"network" info:"Flow network to generate for"`
}

const envPrefix = "FLOW"

const (
	testnet = "testnet"
	mainnet = "mainnet"
)

const (
	testnetFungibleTokenAddress = "9a0766d93b6608b7"
	testnetFlowTokenAddress     = "7e60df042a9c0868"
	testnetIDTableAddress       = "9eca2b38b18b5dfe"
	testnetStakingProxyAddress  = "7aad92e5a0715d21"
	testnetLockedTokensAddress  = "95e019a17d0e23d7"
)

const (
	mainnetFungibleTokenAddress = "f233dcee88fe0abe"
	mainnetFlowTokenAddress     = "1654653399040a61"
	mainnetIDTableAddress       = "8624b52f9ddcd04a"
	mainnetStakingProxyAddress  = "62430cf28c26d095"
	mainnetLockedTokensAddress  = "8d0e87b65159ae63"
)

var conf Config

var cmd = &cobra.Command{
	Use:   "manifest <outfile>",
	Short: "Generate a JSON manifest of all core transaction templates",
	Args:  cobra.ExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		env, err := getEnv(conf)
		if err != nil {
			exit(err)
		}

		manifest := generateManifest(env)

		b, err := json.MarshalIndent(manifest, "", "  ")
		if err != nil {
			exit(err)
		}

		outfile := args[0]

		err = ioutil.WriteFile(outfile, b, 0777)
		if err != nil {
			exit(err)
		}
	},
}

func getEnv(conf Config) (templates.Environment, error) {

	if conf.Network == testnet {
		return templates.Environment{
			Network:              testnet,
			FungibleTokenAddress: testnetFungibleTokenAddress,
			FlowTokenAddress:     testnetFlowTokenAddress,
			IDTableAddress:       testnetIDTableAddress,
			StakingProxyAddress:  testnetStakingProxyAddress,
			LockedTokensAddress:  testnetLockedTokensAddress,
		}, nil
	}

	if conf.Network == mainnet {
		return templates.Environment{
			Network:              mainnet,
			FungibleTokenAddress: mainnetFungibleTokenAddress,
			FlowTokenAddress:     mainnetFlowTokenAddress,
			IDTableAddress:       mainnetIDTableAddress,
			StakingProxyAddress:  mainnetStakingProxyAddress,
			LockedTokensAddress:  mainnetLockedTokensAddress,
		}, nil
	}

	return templates.Environment{}, fmt.Errorf("invalid network %s", conf.Network)
}

func init() {
	initConfig()
}

func initConfig() {
	err := sconfig.New(&conf).
		FromEnvironment(envPrefix).
		BindFlags(cmd.PersistentFlags()).
		Parse()
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	if err := cmd.Execute(); err != nil {
		exit(err)
	}
}

func exit(err error) {
	fmt.Println(err)
	os.Exit(1)
}
