import { PackagePublishResult } from '@scallop-dao/sui-package-kit';

export const dumpObjectIds = (result: PackagePublishResult) => {
  const createdObjects = result.created;

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
    btc: {
      coinId: '',
      metadataId: '',
      treasuryId: '',
    }
  }

  const marketData = {
    adminCapId: '',
    marketId: '',
    CoinDecimalsRegistryId: '',
  }

  const oracleData = {
    priceFeedHolderId: '',
    priceFeedCapId: '',
  }

  const pkgId = result.packageId;
  const fillCoinData = (obj: { type: string, objectId: string }, coinName: keyof (typeof testCoinData)) => {
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

  const fillMarketData = (obj: { type: string, objectId: string }) => {
    const marketType = `${pkgId}::market::Market`;
    const adminCapType = `${pkgId}::app::AdminCap`;
    const coinDecimalsRegistryType = `${pkgId}::coin_decimals_registry::CoinDecimalsRegistry`;

    if (obj.type === marketType) {
      marketData.marketId = obj.objectId;
    } else if (obj.type === coinDecimalsRegistryType) {
      marketData.CoinDecimalsRegistryId = obj.objectId;
    } else if (obj.type === adminCapType) {
      marketData.adminCapId = obj.objectId;
    }
  }

  const fillOracleData = (obj: { type: string, objectId: string }) => {
    const priceFeedHolderType = `${pkgId}::price_feed::PriceFeedHolder`;
    const priceFeedCapType = `${pkgId}::price_feed::PriceFeedCap`;

    if (obj.type === priceFeedHolderType) {
      oracleData.priceFeedHolderId = obj.objectId;
    } else if (obj.type === priceFeedCapType) {
      oracleData.priceFeedCapId = obj.objectId;
    }
  }

  for (const obj of createdObjects) {
    fillCoinData(obj, 'usdc');
    fillCoinData(obj, 'eth');
    fillCoinData(obj, 'btc');
    fillMarketData(obj);
    fillOracleData(obj);
  }

  const packageData = {
    packageId: result.packageId,
    upgradeCapId: result.upgradeCapId,
  }

  return { testCoinData, marketData, oracleData, packageData }
}
