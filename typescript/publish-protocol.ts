import { RawSigner } from "@mysten/sui.js";
import { SuiPackagePublisher, PackagePublishResult } from "@scallop-dao/sui-package-kit";

export const publishProtocol = async (pkgPath: string, signer: RawSigner) => {
  const publisher = new SuiPackagePublisher();
  const gasBudget = 10 ** 10;
  const publishResult = await publisher.publishPackage(pkgPath, signer, {
    gasBudget,
    withUnpublishedDependencies: true,
    skipFetchLatestGitDeps: true
  });
  const protocolData = await extractProtocolData(publishResult);
  return protocolData;
}
const extractProtocolData = async (result: PackagePublishResult) => {
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
    coinDecimalsRegistryId: '',
  }

  const oracleData = {
    switchboard: {
      registryId: '',
      registryCapId: '',
      bundleId: '',
    }
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
      marketData.coinDecimalsRegistryId = obj.objectId;
    } else if (obj.type === adminCapType) {
      marketData.adminCapId = obj.objectId;
    }
  }

  const fillOracleData = (obj: { type: string, objectId: string }) => {
    const switchboardRegistryType = `${pkgId}::switchboard_registry::SwitchboardRegistry`;
    const switchboardRegistryCapType = `${pkgId}::switchboard_registry::SwitchboardRegistryCap`;
    const switchboardBundleType = `${pkgId}::switchboard_adaptor::SwitchboardBundle`;

    if (obj.type === switchboardRegistryType) {
      oracleData.switchboard.registryId = obj.objectId;
    } else if (obj.type === switchboardRegistryCapType) {
      oracleData.switchboard.registryCapId = obj.objectId;
    } else if (obj.type === switchboardBundleType) {
      oracleData.switchboard.bundleId = obj.objectId;
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

  return {
    testCoinData,
    marketData,
    packageData,
    oracleData,
    txn: result.publishTxn,
  }
}
type PromiseResolvedType<T> = T extends Promise<infer R> ? R : never;
export type ProtocolPublishData = PromiseResolvedType<ReturnType<typeof extractProtocolData>>;
