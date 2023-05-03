import { PackagePublishResult } from "@scallop-dao/sui-package-kit";

export const extractObjects = (
  results: { publishResult: PackagePublishResult, packageName: string }[],
) => {

  const testCoinData = {
    usdc: {
      coinId: '',
      metadataId: '',
      treasuryId: '',
    },
    eth: {
      coinId: '',
      metadataId: '',
      treasuryId: '',
    },
    usdt: {
      coinId: '',
      metadataId: '',
      treasuryId: '',
    },
    btc: {
      coinId: '',
      metadataId: '',
      treasuryId: '',
    },
  }

  const marketData = {
    adminCapId: '',
    marketId: '',
    coinDecimalsRegistryId: '',
  }

  const oracleData = {
    switchboard: {
      registryId: '',
      registryCapId: '',
      bundleId: '',
    }
  }

  const packageIds: Record<string, string> = {};

  const fillCoinData = (
    publishResult: PackagePublishResult,
    coinName: keyof (typeof testCoinData)
  ) => {
    const pkgId = publishResult.packageId;
    const createdObjects = publishResult.created;
    for (const obj of createdObjects) {
      const coinStructType = `${pkgId}::${coinName}::${coinName.toUpperCase()}`
      const coinType = `0x2::coin::Coin<${coinStructType}>`
      const coinMetadataType = `0x2::coin::CoinMetadata<${coinStructType}>`
      const coinTreasuryType = `${pkgId}::${coinName}::Treasury`

      if (obj.type === coinType) {
        testCoinData[coinName].coinId = obj.objectId;
      } else if (obj.type === coinMetadataType) {
        testCoinData[coinName].metadataId = obj.objectId;
      } else if (obj.type === coinTreasuryType) {
        testCoinData[coinName].treasuryId = obj.objectId;
      }
    }
  }

  const fillMarketData = (
    publishResult: PackagePublishResult,
  ) => {
    const pkgId = publishResult.packageId;
    const marketType = `${pkgId}::market::Market`;
    const adminCapType = `${pkgId}::app::AdminCap`;
    const coinDecimalsRegistryType = `${pkgId}::coin_decimals_registry::CoinDecimalsRegistry`;
    for (const obj of publishResult.created) {
      if (obj.type === marketType) {
        marketData.marketId = obj.objectId;
      } else if (obj.type === coinDecimalsRegistryType) {
        marketData.coinDecimalsRegistryId = obj.objectId;
      } else if (obj.type === adminCapType) {
        marketData.adminCapId = obj.objectId;
      }
    }
  }

  const fillOracleData = (
    publishResult: PackagePublishResult,
  ) => {
    const pkgId = publishResult.packageId;
    const switchboardRegistryType = `${pkgId}::switchboard_registry::SwitchboardRegistry`;
    const switchboardRegistryCapType = `${pkgId}::switchboard_registry::SwitchboardRegistryCap`;
    const switchboardBundleType = `${pkgId}::switchboard_adaptor::SwitchboardBundle`;

    for (const obj of publishResult.created) {
      if (obj.type === switchboardRegistryType) {
        oracleData.switchboard.registryId = obj.objectId;
      } else if (obj.type === switchboardRegistryCapType) {
        oracleData.switchboard.registryCapId = obj.objectId;
      } else if (obj.type === switchboardBundleType) {
        oracleData.switchboard.bundleId = obj.objectId;
      }
    }
  }

  for (const result of results) {
    packageIds[result.packageName] = result.publishResult.packageId;
    fillCoinData(result.publishResult, 'usdc');
    fillCoinData(result.publishResult, 'eth');
    fillCoinData(result.publishResult, 'btc');
    fillCoinData(result.publishResult, 'usdt');
    fillMarketData(result.publishResult);
    fillOracleData(result.publishResult);
  }

  return {
    testCoinData,
    marketData,
    oracleData,
    packageIds,
  }
}
export type ProtocolPublishData = ReturnType<typeof extractObjects>;
