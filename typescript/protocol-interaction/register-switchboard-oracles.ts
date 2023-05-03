import * as path from 'path';
import * as fs from 'fs';
import { SuiTransactionBlockResponse, getObjectChanges, getObjectFields, getExecutionStatusType } from '@mysten/sui.js';
import { SuiTxBlock } from '@scallop-dao/sui-kit';
import { suiKit, networkType } from '../sui-kit-instance';
import { OracleTxBuilder } from './txbuilders/oracle-txbuilder';
import { TestSwitchboardAggregatorTxBuilder } from './txbuilders/test-switchboard-aggregator-txbuilder';
import type { ProtocolPublishData } from '../package-publish/extract-objects-from-publish-results';

/**
 * If we have switchboard config, we just use the existing aggregators in the config
 * If we don't have switchboard config, we create test aggregators
 * Then, we register these aggregators to our oracle package
 * @param data
 */
export const handleSwitchboard = async (data: ProtocolPublishData) => {
  const potentialSwitchboardConfig = path.join(__dirname, `../../switchboard-oracle.${networkType}.json`);
  const testCoinPkgId = data.packageIds.TestCoin;
  const aggregators = fs.existsSync(potentialSwitchboardConfig)
    ? require(potentialSwitchboardConfig).aggregators
    : await createTestSwitchboardAggregators(data);

  const switchboardPairs: { aggregatorId: string, coinType: string  }[] = [
    { aggregatorId: aggregators.eth_usd, coinType: `${testCoinPkgId}::eth::ETH` },
    { aggregatorId: aggregators.btc_usd, coinType: `${testCoinPkgId}::btc::BTC` },
    { aggregatorId: aggregators.usdc_usd, coinType: `${testCoinPkgId}::usdc::USDC` },
    { aggregatorId: aggregators.usdt_usd, coinType: `${testCoinPkgId}::usdt::USDT` },
  ];
  const res = await registerSwitchboardOracles(data, switchboardPairs);
  return getExecutionStatusType(res) === 'success' ? { aggregators, ok: true } : { aggregators, ok: false }
}

export const createTestSwitchboardAggregators = async (data: ProtocolPublishData) => {
  const suiTxBlock = new SuiTxBlock();
  const testSwitchboardAggregatorTxBuilder = new TestSwitchboardAggregatorTxBuilder(
    data.packageIds.TestSwitchboardAggregator,
  );
  const aggregatorList = [
    { name: 'ETH/USD', value: 2000, scaleFactor: 0 },
    { name: 'USDC/USD', value: 1, scaleFactor: 0 },
    { name: 'USDT/USD', value: 1, scaleFactor: 0 },
    { name: 'BTC/USD', value: 28000, scaleFactor: 0 },
    { name: 'SUI/USD', value: 2, scaleFactor: 0 },
  ]
  for (const aggregator of aggregatorList) {
    testSwitchboardAggregatorTxBuilder.initAggregator(
      suiTxBlock,
      aggregator.name,
      aggregator.value,
      aggregator.scaleFactor,
    )
  }
  const createAggregatorsTxn = await suiKit.signAndSendTxn(suiTxBlock);
  const { testSwitchboardAggregators } = await parseCreateAggregatorsTransaction(createAggregatorsTxn);
  return testSwitchboardAggregators;
}
export const registerSwitchboardOracles = async (data: ProtocolPublishData, switchboardPairs: { aggregatorId: string, coinType: string }[]) => {
  const oracleTxBuilder = new OracleTxBuilder(
    data.packageIds.Oracle,
    data.oracleData.switchboard.registryId,
    data.oracleData.switchboard.registryCapId,
    data.oracleData.switchboard.bundleId,
  );
  const registerAggregatorTxnBlock = new SuiTxBlock();
  for (const pair of switchboardPairs) {
    oracleTxBuilder.registrySwitchboardAggregator(
      registerAggregatorTxnBlock,
      pair.aggregatorId,
      pair.coinType,
    );
  }
  registerAggregatorTxnBlock.txBlock.setGasBudget(10 ** 9);
  return await suiKit.signAndSendTxn(registerAggregatorTxnBlock);
}
const parseCreateAggregatorsTransaction = async (suiResponse: SuiTransactionBlockResponse) => {
  const objectChanges = getObjectChanges(suiResponse);
  const switchboardData = {
    eth_usd: '',
    usdc_usd: '',
    usdt_usd: '',
    btc_usd: '',
    sui_usd: '',
  };

  if (objectChanges) {
    for (const change of objectChanges) {
      if (change.type === 'created' && change.objectType.endsWith('aggregator::Aggregator')) {
        const oracle = await parseSwitchboardOracle(change.objectId);
        if (oracle.name === 'ETH/USD') {
          switchboardData.eth_usd = change.objectId;
        } else if (oracle.name === 'USDC/USD') {
          switchboardData.usdc_usd = change.objectId;
        } else if (oracle.name === 'BTC/USD') {
          switchboardData.btc_usd = change.objectId;
        } else if (oracle.name === 'SUI/USD') {
          switchboardData.sui_usd = change.objectId;
        } else if (oracle.name === 'USDT/USD') {
          switchboardData.usdt_usd = change.objectId;
        }
      }
    }
  }
  return { testSwitchboardAggregators: switchboardData };
}

export const parseSwitchboardOracle = async (aggregatorId: string) => {
  const aggregator = await suiKit.provider().getObject({
    id: aggregatorId,
    options: {
      showContent: true
    }
  });
  const fields = getObjectFields(aggregator) as {name: Uint8Array};
  return {
    name: Buffer.from(fields.name).toString()
  }
}
