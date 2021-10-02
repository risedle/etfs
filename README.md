# Risedle ETFs

![This is us anon!](./meme.png)

This repository contains smart contract for decentralized leveraged ETFs.

- Website: [risedle.com](https://risedle.com)
- Docs: [docs.risedle.com](https://docs.risedle.com)
- Twitter: [@risedle](https://twitter.com/risedle)
- Whitepaper: [ETHRISE Whitepaper](https://observablehq.com/@pyk/ethrise)

## Install

Requires [dapp.tools](https://github.com/dapphub/dapptools#installation).

1. Clone Risedle
   ```
   git clone git@github.com:risedle/etfs.git
   cd etfs/
   ```
2. Download all the dependencies
   ```
   dapp update
   ```
3. Configure and run the test

## Configure

Copy `.dapprc.example` to `.dapprc` and edit the `ETH_RPC_URL`.

## Run the test

Run the following command to run the test against Ethereum mainnet:

      CHAIN=ethereum make test

Use this command to run the test against Arbitrum One mainnet:

      CHAIN=arbitrum make test

here is the example output:

      Running 3 tests for src/test/Hevm.t.sol:HevmTest
      [PASS] test_setUSDTBalance() (gas: 13698)
      [PASS] test_setWETHBalance() (gas: 11267)
      [PASS] test_setUSDCBalance() (gas: 18526)

      Running 4 tests for src/test/RisedleETFExternal.t.sol:RisedleETFExternalTest
      [PASS] test_SetVaultAfterDeployment() (gas: 6107018)
      [PASS] test_GovernorCanUpdateFreeReceiver() (gas: 6111789)
      [PASS] testFail_NonGovernorCannotUpdateFeeReceiver() (gas: 6148497)
      [PASS] testFail_SetVaultOnlyCalledOnce() (gas: 6107293)

      Running 1 tests for src/test/RisedleETFInternal.t.sol:RisedleETFInternalTest
      [PASS] test_ETFProperties() (gas: 13426)

      Running 17 tests for src/test/RisedleVaultExternal.t.sol:RisedleVaultExternalTest
      [PASS] test_LenderCanRemoveSupplyFromTheVault() (gas: 4833261)
      [PASS] test_GovernorCanUpdateVaultParameters() (gas: 3944778)
      [PASS] test_LenderShouldEarnInterest() (gas: 5578959)
      [PASS] test_GovernorCanUpdateFeeReceiverAddress() (gas: 3939985)
      [PASS] test_AuthorizedBorrowerCanRepayToTheVault() (gas: 5587454)
      [PASS] test_LenderCanAddSupplytToTheVault() (gas: 4759698)
      [PASS] test_AnyoneCanCollectPendingFeesToFeeReceiver() (gas: 5713409)
      [PASS] test_GovernorIsProperlySet() (gas: 3945107)
      [PASS] test_BorrowersDebtShouldIncreasedProportionally() (gas: 6361578)
      [PASS] testFail_NonGovernorCannotUpdateFeeReceiverAddress() (gas: 3977944)
      [PASS] testFail_NonGovernorCannotUpdateVaultParameters() (gas: 3976614)
      [PASS] test_GovernorCanGrantBorrower() (gas: 4615699)
      [PASS] test_AuthorizedBorrowerCanBorrowFromTheVault() (gas: 5541331)
      [PASS] testFail_UnauthorizedBorrowerCannotBorrowFromTheVault() (gas: 5445309)
      [PASS] testFail_UnauthorizedBorrowerCannotRepayToTheVault() (gas: 4655713)
      [PASS] test_LendersShouldEarnInterestProportionally() (gas: 6414942)
      [PASS] test_AnyoneCanAccrueInterest() (gas: 3961500)

      Running 9 tests for src/test/RisedleVaultInternal.t.sol:RisedleVaultInternalTest
      [PASS] test_GetDebtProportionRateInEther() (gas: 48305)
      [PASS] test_GetTotalAvailableCash() (gas: 44068)
      [PASS] test_VaultProperties() (gas: 20518)
      [PASS] test_GetUtilizationRateInEther() (gas: 3098)
      [PASS] test_GetBorrowRatePerSecondInEther() (gas: 11508)
      [PASS] test_GetExchangeRateInEther() (gas: 165111)
      [PASS] test_UpdateVaultStates() (gas: 49928)
      [PASS] test_AccrueInterest() (gas: 103581)
      [PASS] test_GetInterestAmount() (gas: 2467)

## Gas Report

Run the following command to get deployment gas report:

      export ETH_RPC_URL=<rpc url here>
      make gas

Here is the example output:

      ./scripts/risedle-vault-gas-with-build-optimization.sh
      Risedle Vault with DAPP_BUILD_OPTIMIZE=1
      Deployment gas usage: 2513337
      ./scripts/risedle-vault-gas-without-build-optimization.sh
      Risedle Vault with DAPP_BUILD_OPTIMIZE=0
      Deployment gas usage: 3644718
      ./scripts/risedle-etf-gas-with-build-optimization.sh
      Risedle ETF with DAPP_BUILD_OPTIMIZE=1
      Deployment gas usage: 1137986
      ./scripts/risedle-etf-gas-without-build-optimization.sh
      Risedle ETF with DAPP_BUILD_OPTIMIZE=0
      Deployment gas usage: 1761578

### VSCode

Install the following VSCode extension:

1. [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
   for code formatter.
2. [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity)
   for code highlight and more.
