#!/usr/bin/env bash

set -eo pipefail

# Build and perform optimization first
export DAPP_BUILD_OPTIMIZE=1
export DAPP_BUILD_OPTIMIZE_RUNS=1000000000
CHAIN=ethereum dapp build &> /dev/null

# select the filename and the contract in it
CONTRACT_NAME="Empty"
PATTERN=".contracts[\"src/$CONTRACT_NAME.sol\"].$CONTRACT_NAME"
ABI=$(jq -r "$PATTERN.abi" out/dapp.sol.json)
SIG=$(echo $ABI | seth --abi-constructor)
BYTECODE=0x$(jq -r "$PATTERN.evm.bytecode.object" out/dapp.sol.json)

# estimate gas
GAS=$(seth estimate --create $BYTECODE $SIG)

echo "Empty contract with DAPP_BUILD_OPTIMIZE=1"
echo "Deployment gas usage:" $GAS
