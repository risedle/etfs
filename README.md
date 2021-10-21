# Risedle ETFs

![This is us anon!](./meme.png)

This repository contains smart contract for decentralized leveraged ETFs.

The frontend is available [here](https://github.com/risedle/frontend).

- Website: [demo.risedle.com](https://demo.risedle.com)
- Docs: [docs.risedle.com](https://docs.risedle.com)
- Twitter: [@risedle](https://twitter.com/risedle)
- Whitepaper: [ETHRISE Whitepaper](https://observablehq.com/@pyk/ethrise)

## Deployment

The smart contract is available on Kovan:

- Risedle [0x4576Df8E6C99d7Bb71Aa9E843BfbE9111D5ff256](https://kovan.etherscan.io/address/0x4576Df8E6C99d7Bb71Aa9E843BfbE9111D5ff256)
- ETHRISE [0xb1bd881ef4ef1975f7b19b23da52558708c4fddb](https://kovan.etherscan.io/address/0xb1bd881ef4ef1975f7b19b23da52558708c4fddb)
- Risedle USDC Faucet [0x64249d73AF4C3ABC7A9704Bf02188fa36d0B1Ed9](https://kovan.etherscan.io/address/0x64249d73AF4C3ABC7A9704Bf02188fa36d0B1Ed9)
- Risedle WETH Faucet [0x1d6D78d75c641C4256DE628e4dAFF53eFa7d116E](https://kovan.etherscan.io/address/0x1d6D78d75c641C4256DE628e4dAFF53eFa7d116E)

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

      [PASS] test_getETHUSDCPrice() (gas: 57539)

      Running 1 tests for src/test/CurveSwap.t.sol:CurveSwapTest
      [PASS] test_SwapUSDCToWETH() (gas: 27533)

      Running 3 tests for src/test/Hevm.t.sol:HevmTest
      [PASS] test_setUSDTBalance() (gas: 13698)
      [PASS] test_setWETHBalance() (gas: 11267)
      [PASS] test_setUSDCBalance() (gas: 18526)

      Running 4 tests for src/test/RisedleETFTokenAccessControl.t.sol:RisedleETFTokenAccessControl
      [PASS] testFail_NonGovernanceCannotMintToken() (gas: 1660983)
      [PASS] testFail_NonGovernanceCannotBurnToken() (gas: 1715299)
      [PASS] test_GovernanceCanBurnToken() (gas: 1713852)
      [PASS] test_GovernanceCanMintToken() (gas: 1709342)

      Running 8 tests for src/test/RisedleMarketAccessControl.t.sol:RisedleMarketAccessControlTest
      [PASS] test_GovernanceIsProperlySet() (gas: 4977069)
      [PASS] test_GovernanceCanSetFeeRecipientAddress() (gas: 4982806)
      [PASS] testFail_NonGovernanceCannotSetFeeRecipientAddress() (gas: 4985801)
      [PASS] testFail_NonGovernanceCannotSetVaultParameters() (gas: 4984538)
      [PASS] test_GovernanceCanSetVaultParameters() (gas: 4984700)
      [PASS] testFail_NonGovernanceCannotCreateNewETF() (gas: 4987469)
      [PASS] test_GovernanceCanCreateNewETF() (gas: 5133440)
      [PASS] test_AnyoneCanAccrueInterest() (gas: 4984059)

      Running 6 tests for src/test/RisedleMarketExternal.t.sol:RisedleMarketExternalTest
      [PASS] test_LenderCanRemoveSupplyFromTheVault() (gas: 5876060)
      [PASS] test_LenderCanAddSupplytToTheVault() (gas: 5809925)
      [PASS] test_InvestorCanMintETFToken() (gas: 8344951)
      [PASS] test_InvestorMintTwice() (gas: 8482115)
      [PASS] testFail_InvestorCannotMintETFTokenIfNoSupplyAvailable() (gas: 8090668)
      [PASS] test_InvestorCanRedeemETFToken() (gas: 8514927)

      Running 20 tests for src/test/RisedleMarketInternal.t.sol:RisedleMarketInternalTest
      [PASS] test_CalculateBorrowRatePerSecondInEther() (gas: 11466)
      [PASS] test_CalculateETFNAV() (gas: 1781)
      [PASS] test_GetDebtProportionRateInEther() (gas: 48288)
      [PASS] test_GetTotalAvailableCash() (gas: 54086)
      [PASS] test_SetVaultStates() (gas: 71021)
      [PASS] test_VaultProperties() (gas: 19010)
      [PASS] testFail_GetCollateralPerETFFeeTooLarge() (gas: 1042)
      [PASS] test_GetChainlinkPriceInGwei() (gas: 44894)
      [PASS] test_GetCollateralPrice() (gas: 46125)
      [PASS] test_GetUtilizationRateInEther() (gas: 90497)
      [PASS] test_GetSupplyRatePerSecondInEther() (gas: 69085)
      [PASS] test_GetBorrowRatePerSecondInEther() (gas: 56017)
      [PASS] test_CalculateUtilizationRateInEther() (gas: 3097)
      [PASS] test_GetExchangeRateInEther() (gas: 170657)
      [PASS] test_AccrueInterest() (gas: 111911)
      [PASS] test_GetCollateralAndFeeAmount() (gas: 1906)
      [PASS] test_GetDebtPerETF() (gas: 110703)
      [PASS] test_SwapExactOutputSingle() (gas: 191249)
      [PASS] test_GetCollateralPerETF() (gas: 2915)
      [PASS] test_GetInterestAmount() (gas: 2489)

      Running 2 tests for src/test/UniswapV3.t.sol:UniswapV3Test
      [PASS] test_BorrowAndSwap() (gas: 229397)
      [PASS] test_SwapUSDCToWETH() (gas: 136528)

## Gas Report

Run the following command to get deployment gas report:

      export ETH_RPC_URL=<rpc url here>
      make gas

Here is the example output:

      ./scripts/empty-gas-with-build-optimization.sh
      Empty contract with DAPP_BUILD_OPTIMIZE=1
      Deployment gas usage: 67066
      ./scripts/risedle-gas-with-build-optimization.sh
      Risedle with DAPP_BUILD_OPTIMIZE=1
      Deployment gas usage: 3617147
      ./scripts/risedle-gas-without-build-optimization.sh
      Risedle with DAPP_BUILD_OPTIMIZE=0
      Deployment gas usage: 5138125

### VSCode

Install the following VSCode extension:

1. [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)
   for code formatter.
2. [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity)
   for code highlight and more.
