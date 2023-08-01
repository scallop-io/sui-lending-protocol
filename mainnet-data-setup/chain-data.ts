
import { SUI_TYPE_ARG } from '@mysten/sui.js';

export type SupportedCollaterals = 'sui' | 'wormholeUsdc' | 'wormholeUsdt' | 'wormholeEth';

export type SupportedBaseAssets = 'sui' | 'wormholeUsdc' | 'wormholeUsdt' | 'wormholeEth';

export const wormholeUsdcCoinMetadataId = '0x4fbf84f3029bd0c0b77164b587963be957f853eccf834a67bb9ecba6ec80f189';
export const wormholeUsdcDecimal = 6;
export const wormholeUsdtCoinMetadataId = '0xfb0e3eb97dd158a5ae979dddfa24348063843c5b20eb8381dd5fa7c93699e45c';
export const wormholeUsdtDecimal = 6;

export const wormholeEthCoinMetadataId = '0x8900e4ceede3363bef086d6b50ca89d816d0e90bf6bc46efefe1f8455e08f50f';
export const wormholeEthDecimal = 8;

export const suiDecimal = 9;


export const wormholeUsdcType = '0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN';

export const wormholeUsdtType = '0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN';

export const wormholeEthType = '0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade5874359610ef8eeced5::coin::COIN';


export const coinTypes = {
  sui: SUI_TYPE_ARG,
  wormholeUsdc: wormholeUsdcType,
  wormholeUsdt: wormholeUsdtType,
  wormholeEth: wormholeEthType,
};

export const coinMetadataIds = {
  wormholeUsdc: wormholeUsdcCoinMetadataId,
  wormholeUsdt: wormholeUsdtCoinMetadataId,
  wormholeEth: wormholeEthCoinMetadataId,
}
