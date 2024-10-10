import { SupportedBaseAssets } from "./chain-data";
import type { BorrowFee } from 'contracts/protocol';

export const borrowFees: Record<SupportedBaseAssets, BorrowFee> = {
  sui: { numerator: 0, denominator: 1000 },
  sca: { numerator: 0, denominator: 1000 },
  cetus: { numerator: 0, denominator: 1000 },
  afSui: { numerator: 0, denominator: 1000 },
  haSui: { numerator: 0, denominator: 1000 },
  vSui: { numerator: 0, denominator: 1000 },
  wormholeEth: { numerator: 0, denominator: 1000 },
  wormholeUsdc: { numerator: 0, denominator: 1000 },
  wormholeUsdt: { numerator: 0, denominator: 1000 },
  wormholeBtc: { numerator: 0, denominator: 1000 },
  wormholeSol: { numerator: 0, denominator: 1000 },
  nativeUsdc: { numerator: 0, denominator: 1000 },
}
