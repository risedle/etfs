# Risedle ETFs

![This is us anon!](./meme.png)

This repository contains smart contract for decentralized leveraged ETFs.

The frontend is available [here](https://github.com/risedle/frontend).

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

      Running 1 tests for src/test/ChainlinkPrice.t.sol:ChainlinkTest
      [PASS] test_getETHUSDCPrice() (gas: 52852)

      Running 1 tests for src/test/CurveSwap.t.sol:CurveSwapTest
      [PASS] test_SwapUSDCToWETH() (gas: 24446)

      Running 3 tests for src/test/Hevm.t.sol:HevmTest
      [PASS] test_setUSDTBalance() (gas: 11008)
      [PASS] test_setWETHBalance() (gas: 8476)
      [PASS] test_setUSDCBalance() (gas: 15769)

      Running 8 tests for src/test/RisedleAccessControl.t.sol:RisedleAccessControlTest
      [PASS] test_GovernanceIsProperlySet() (gas: 3401666)
      [PASS] test_GovernanceCanSetFeeRecipientAddress() (gas: 3404592)
      [PASS] testFail_NonGovernanceCannotSetFeeRecipientAddress() (gas: 3407248)
      [PASS] testFail_NonGovernanceCannotSetVaultParameters() (gas: 3405915)
      [PASS] test_GovernanceCanSetVaultParameters() (gas: 3406520)
      [PASS] testFail_NonGovernanceCannotCreateNewETF() (gas: 3407678)
      [PASS] test_GovernanceCanCreateNewETF() (gas: 3550337)
      [PASS] test_AnyoneCanAccrueInterest() (gas: 3406522)

      Running 4 tests for src/test/RisedleETFTokenAccessControl.t.sol:RisedleETFTokenAccessControl
      [PASS] testFail_NonGovernanceCannotMintToken() (gas: 1059225)
      [PASS] testFail_NonGovernanceCannotBurnToken() (gas: 1110626)
      [PASS] test_GovernanceCanBurnToken() (gas: 1110108)
      [PASS] test_GovernanceCanMintToken() (gas: 1106652)

      Running 5 tests for src/test/RisedleExternal.t.sol:RisedleExternalTest
      [PASS] test_LenderCanRemoveSupplyFromTheVault() (gas: 4101938)
      [PASS] test_LenderCanAddSupplytToTheVault() (gas: 4033595)
      [PASS] test_InvestorCanMintETFToken() (gas: 5859629)
      [PASS] testFail_InvestorCannotMintETFTokenIfNoSupplyAvailable() (gas: 5639940)
      [PASS] test_InvestorCanRedeemETFToken() (gas: 6009168)

      Running 20 tests for src/test/RisedleInternal.t.sol:RisedleInternalTest
      [PASS] test_CalculateBorrowRatePerSecondInEther() (gas: 7250)
      [PASS] test_CalculateETFNAV() (gas: 1157)
      [PASS] test_GetDebtProportionRateInEther() (gas: 47423)
      [PASS] test_GetTotalAvailableCash() (gas: 47395)
      [PASS] test_SetVaultStates() (gas: 69390)
      [PASS] test_VaultProperties() (gas: 16925)
      [PASS] testFail_GetCollateralPerETFFeeTooLarge() (gas: 736)
      [PASS] test_GetChainlinkPriceInGwei() (gas: 42523)
      [PASS] test_GetCollateralPrice() (gas: 43197)
      [PASS] test_GetUtilizationRateInEther() (gas: 79084)
      [PASS] test_GetSupplyRatePerSecondInEther() (gas: 64223)
      [PASS] test_GetBorrowRatePerSecondInEther() (gas: 49318)
      [PASS] test_CalculateUtilizationRateInEther() (gas: 1923)
      [PASS] test_GetExchangeRateInEther() (gas: 161268)
      [PASS] test_AccrueInterest() (gas: 93902)
      [PASS] test_GetCollateralAndFeeAmount() (gas: 1124)
      [PASS] test_GetDebtPerETF() (gas: 103007)
      [PASS] test_SwapExactOutputSingle() (gas: 178081)
      [PASS] test_GetCollateralPerETF() (gas: 1813)
      [PASS] test_GetInterestAmount() (gas: 1706)

      Running 2 tests for src/test/UniswapV3.t.sol:UniswapV3Test
      [PASS] test_BorrowAndSwap() (gas: 199510)
      [PASS] test_SwapUSDCToWETH() (gas: 134780)

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
