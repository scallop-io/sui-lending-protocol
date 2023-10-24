
import { SUI_TYPE_ARG } from '@mysten/sui.js';

export type SupportedCollaterals =
  | 'sui'
  | 'cetus'
  | 'afSui'
  | 'haSui'
  | 'wormholeUsdc'
  | 'wormholeUsdt'
  | 'wormholeEth'
;

export type SupportedBaseAssets =
  | 'sui'
  | 'cetus'
  | 'afSui'
  | 'haSui'
  | 'wormholeUsdc'
  | 'wormholeUsdt'
  | 'wormholeEth'
;

export const coinTypes = {
  sui: SUI_TYPE_ARG,
  cetus: '0x06864a6f921804860930db6ddbe2e16acdf8504495ea7481637a1c8b9a8fe54b::cetus::CETUS',
  afSui: '0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI',
  haSui: '0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI',
  wormholeUsdc: '0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN',
  wormholeUsdt: '0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN',
  wormholeEth: '0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade5874359610ef8eeced5::coin::COIN',
  wormholeSol: '0xb7844e289a8410e50fb3ca48d69eb9cf29e27d223ef90353fe1bd8e27ff8f3f8::coin::COIN',
  wormholeApt: '0x3a5143bb1196e3bcdfab6203d1683ae29edd26294fc8bfeafe4aaa9d2704df37::coin::COIN',
  wormholeBtc: '0x027792d9fed7f9844eb4839566001bb6f6cb4804f66aa2da6fe1ee242d896881::coin::COIN',
};

export const coinMetadataIds = {
  sui: '0x9258181f5ceac8dbffb7030890243caed69a9599d2886d957a9cb7656af3bdb3',
  cetus: '0x4c0dce55eff2db5419bbd2d239d1aa22b4a400c01bbb648b058a9883989025da',
  afSui: '0x2f9217f533e51334873a39b8026a4aa6919497b47f49d0986a4f1aec66f8a34d',
  haSui: '0x2c5f33af93f6511df699aaaa5822d823aac6ed99d4a0de2a4a50b3afa0172e24',
  wormholeUsdc: '0x4fbf84f3029bd0c0b77164b587963be957f853eccf834a67bb9ecba6ec80f189',
  wormholeUsdt: '0xfb0e3eb97dd158a5ae979dddfa24348063843c5b20eb8381dd5fa7c93699e45c',
  wormholeEth: '0x8900e4ceede3363bef086d6b50ca89d816d0e90bf6bc46efefe1f8455e08f50f',
  wormholeSol: '0x4d2c39082b4477e3e79dc4562d939147ab90c42fc5f3e4acf03b94383cd69b6e',
  wormholeApt: '0xc969c5251f372c0f34c32759f1d315cf1ea0ee5e4454b52aea08778eacfdd0a8',
  wormholeBtc: '0x5d3c6e60eeff8a05b693b481539e7847dfe33013e7070cdcb387f5c0cac05dfd',
};

export const coinDecimals = {
  sui: 9,
  cetus: 9,
  afSui: 9,
  haSui: 9,
  wormholeUsdc: 6,
  wormholeUsdt: 6,
  wormholeEth: 8,
  wormholeSol: 8,
  wormholeApt: 8,
  wormholeBtc: 8,
}
