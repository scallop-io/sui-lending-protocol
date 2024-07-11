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
}
