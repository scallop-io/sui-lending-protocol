import { SupportedBaseAssets } from "./chain-data";
import type { BorrowFee } from 'contracts/protocol';

export const borrowFees: Record<SupportedBaseAssets, BorrowFee> = {
  sui: { numerator: 1, denominator: 1000 },
  cetus: { numerator: 1, denominator: 1000 },
  afSui: { numerator: 1, denominator: 1000 },
  haSui: { numerator: 1, denominator: 1000 },
  vSui: { numerator: 1, denominator: 1000 },
  wormholeEth: { numerator: 1, denominator: 1000 },
  wormholeUsdc: { numerator: 1, denominator: 1000 },
  wormholeUsdt: { numerator: 1, denominator: 1000 },
}
