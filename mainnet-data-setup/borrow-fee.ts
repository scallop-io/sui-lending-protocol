import { SupportedBaseAssets } from "./chain-data";
import type { BorrowFee } from 'contracts/protocol';

export const borrowFees: Record<SupportedBaseAssets, BorrowFee> = {
  sui: { numerator: 3, denominator: 1000 },
  sca: { numerator: 3, denominator: 1000 },
  cetus: { numerator: 3, denominator: 1000 },
  afSui: { numerator: 3, denominator: 1000 },
  haSui: { numerator: 3, denominator: 1000 },
  vSui: { numerator: 3, denominator: 1000 },
  wormholeEth: { numerator: 3, denominator: 1000 },
  wormholeUsdc: { numerator: 3, denominator: 1000 },
  wormholeUsdt: { numerator: 3, denominator: 1000 },
  wormholeBtc: { numerator: 3, denominator: 1000 },
  sbwBTC: { numerator: 3, denominator: 1000 },
  wormholeSol: { numerator: 3, denominator: 1000 },
  nativeUsdc: { numerator: 3, denominator: 1000 },
  sbEth: { numerator: 3, denominator: 1000 },
  fdusd: { numerator: 3, denominator: 1000 },
  deep: { numerator: 10, denominator: 1000 },
  fud: { numerator: 10, denominator: 1000 },
  sbUsdt: { numerator: 3, denominator: 1000 },
  blub: { numerator: 10, denominator: 1000 },
  mUsd: { numerator: 10, denominator: 1000 },
  ns: { numerator: 10, denominator: 1000 },
  usdy: { numerator: 3, denominator: 1000 },
}
