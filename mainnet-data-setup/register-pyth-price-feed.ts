import { SuiTxBlock } from '@scallop-io/sui-kit';
import {
  pythRuleTxBuilder,
} from 'contracts/sui_x_oracle/pyth_rule';
import {
  oracles,
} from './asset-oracles';
import {
  coinTypes,
  SupportedBaseAssets,
} from './chain-data';
import {buildMultiSigTx} from "./multi-sig";
import { suiKit } from 'sui-elements';

const PriceConfidenceToleranceDenominator = 10_000;

const calculatePriceConfidenceTolerance = (tolerance: number) => {
  return Math.floor(tolerance / 100 * PriceConfidenceToleranceDenominator);
}

export const registerPythPriceObject = async () => {
  const tx = new SuiTxBlock();

  const confidenceTolerances: Record<SupportedBaseAssets, number> = {
    sui: calculatePriceConfidenceTolerance(2),
    sca: calculatePriceConfidenceTolerance(2),
    cetus: calculatePriceConfidenceTolerance(2),
    afSui: calculatePriceConfidenceTolerance(2),
    vSui: calculatePriceConfidenceTolerance(2),
    haSui: calculatePriceConfidenceTolerance(2),
    wormholeUsdc: calculatePriceConfidenceTolerance(2),
    wormholeUsdt: calculatePriceConfidenceTolerance(2),
    wormholeEth: calculatePriceConfidenceTolerance(2),
    wormholeSol: calculatePriceConfidenceTolerance(2),
    wormholeBtc: calculatePriceConfidenceTolerance(2),
    nativeUsdc: calculatePriceConfidenceTolerance(2),
    sbEth: calculatePriceConfidenceTolerance(2),
    deep: calculatePriceConfidenceTolerance(2),
    fud: calculatePriceConfidenceTolerance(2),
    fdusd: calculatePriceConfidenceTolerance(2),
    sbUsdt: calculatePriceConfidenceTolerance(2),
    blub: calculatePriceConfidenceTolerance(2),
    sbwBTC: calculatePriceConfidenceTolerance(2),
    mUsd: calculatePriceConfidenceTolerance(2),
    ns: calculatePriceConfidenceTolerance(2),
    usdy: calculatePriceConfidenceTolerance(2),
  };

  for (const coinName in confidenceTolerances) {
    pythRuleTxBuilder.registerPythFeed(tx, oracles[coinName as SupportedBaseAssets].pythPriceObjectId, confidenceTolerances[coinName as SupportedBaseAssets], coinTypes[coinName as SupportedBaseAssets]);
  }
  
  const txBytes = await buildMultiSigTx(tx);
  const resp = await suiKit.provider().dryRunTransactionBlock({
      transactionBlock: txBytes
  })
  console.log(resp.effects.status);
  console.log(resp.balanceChanges);

  return txBytes;
}

registerPythPriceObject().then(console.log);