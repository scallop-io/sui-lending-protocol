import { SuiTransactionBlockResponse, getObjectChanges, getObjectFields } from '@mysten/sui.js';
import { SuiTxBlock } from '@scallop-dao/sui-kit';
import { suiKit } from '../sui-kit-instance';
import { OracleTxBuilder } from './txbuilders/oracle-txbuilder';
import { TestSwitchboardAggregatorTxBuilder } from './txbuilders/test-switchboard-aggregator-txbuilder';
import type { ProtocolPublishData } from '../package-publish/extract-objects-from-publish-results';

export const registerSwitchboardOracles = async ( data: ProtocolPublishData ) => {
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

  const oracleTxBuilder = new OracleTxBuilder(
    data.packageIds.Oracle,
    data.oracleData.switchboard.registryId,
    data.oracleData.switchboard.registryCapId,
    data.oracleData.switchboard.bundleId,
  );
  const registerAggregatorTxnBlock = new SuiTxBlock();
  const switchboardPairs = [
    { aggregatorId: testSwitchboardAggregators.eth_usd, type: `${data.packageIds.TestCoin}::eth::ETH` },
    { aggregatorId: testSwitchboardAggregators.btc_usd, type: `${data.packageIds.TestCoin}::btc::BTC` },
    { aggregatorId: testSwitchboardAggregators.usdc_usd, type: `${data.packageIds.TestCoin}::usdc::USDC` },
    { aggregatorId: testSwitchboardAggregators.usdt_usd, type: `${data.packageIds.TestCoin}::usdt::USDT` },
    { aggregatorId: testSwitchboardAggregators.sui_usd, type: `0x2::sui::SUI` },
  ];
  for (const pair of switchboardPairs) {
    oracleTxBuilder.registrySwitchboardAggregator(
      registerAggregatorTxnBlock,
      pair.aggregatorId,
      pair.type,
    );
  }
  registerAggregatorTxnBlock.txBlock.setGasBudget(10 ** 9);
  const registerAggregatorTxn = await suiKit.signAndSendTxn(registerAggregatorTxnBlock);
  return { testSwitchboardAggregators }
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
