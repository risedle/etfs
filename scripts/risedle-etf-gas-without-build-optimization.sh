#!/usr/bin/env bash

set -eo pipefail

# Build and perform optimization first
export DAPP_BUILD_OPTIMIZE=0
CHAIN=ethereum dapp build &> /dev/null

# select the filename and the contract in it
CONTRACT_NAME="RisedleETF"
PATTERN=".contracts[\"src/$CONTRACT_NAME.sol\"].$CONTRACT_NAME"
ABI=$(jq -r "$PATTERN.abi" out/dapp.sol.json)
SIG=$(echo $ABI | seth --abi-constructor)
BYTECODE=0x$(jq -r "$PATTERN.evm.bytecode.object" out/dapp.sol.json)

# estimate gas
GAS=$(seth estimate --create $BYTECODE $SIG '"ETH 2x Leverage Risedle"' '"ETHRISE"' 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 100000000)

echo "Risedle ETF with DAPP_BUILD_OPTIMIZE=0"
echo "Deployment gas usage:" $GAS
