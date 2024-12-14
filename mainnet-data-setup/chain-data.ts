
import { SUI_TYPE_ARG } from '@mysten/sui.js';

export type SupportedCollaterals =
  | 'sui'
  | 'sca'
  | 'cetus'
  | 'afSui'
  | 'haSui'
  | 'vSui'
  | 'wormholeUsdc'
  | 'wormholeUsdt'
  | 'wormholeEth'
  | 'wormholeSol'
  | 'wormholeBtc'
  | 'nativeUsdc'
  | 'sbEth'
;

export type SupportedBaseAssets =
  | 'sui'
  | 'sca'
  | 'cetus'
  | 'afSui'
  | 'haSui'
  | 'vSui'
  | 'wormholeUsdc'
  | 'wormholeUsdt'
  | 'wormholeEth'
  | 'wormholeSol'
  | 'wormholeBtc'
  | 'nativeUsdc'
  | 'sbEth'
  | 'deep'
  | 'fud'
;

export const coinTypes = {
  sui: SUI_TYPE_ARG,
  sca: '0x7016aae72cfc67f2fadf55769c0a7dd54291a583b63051a5ed71081cce836ac6::sca::SCA',
  cetus: '0x06864a6f921804860930db6ddbe2e16acdf8504495ea7481637a1c8b9a8fe54b::cetus::CETUS',
  afSui: '0xf325ce1300e8dac124071d3152c5c5ee6174914f8bc2161e88329cf579246efc::afsui::AFSUI',
  haSui: '0xbde4ba4c2e274a60ce15c1cfff9e5c42e41654ac8b6d906a57efa4bd3c29f47d::hasui::HASUI',
  vSui: '0x549e8b69270defbfafd4f94e17ec44cdbdd99820b33bda2278dea3b9a32d3f55::cert::CERT',
  wormholeUsdc: '0x5d4b302506645c37ff133b98c4b50a5ae14841659738d6d733d59d0d217a93bf::coin::COIN',
  wormholeUsdt: '0xc060006111016b8a020ad5b33834984a437aaa7d3c74c18e09a95d48aceab08c::coin::COIN',
  wormholeEth: '0xaf8cd5edc19c4512f4259f0bee101a40d41ebed738ade5874359610ef8eeced5::coin::COIN',
  wormholeSol: '0xb7844e289a8410e50fb3ca48d69eb9cf29e27d223ef90353fe1bd8e27ff8f3f8::coin::COIN',
  wormholeApt: '0x3a5143bb1196e3bcdfab6203d1683ae29edd26294fc8bfeafe4aaa9d2704df37::coin::COIN',
  wormholeBtc: '0x027792d9fed7f9844eb4839566001bb6f6cb4804f66aa2da6fe1ee242d896881::coin::COIN',
  nativeUsdc: '0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC',
  sbEth: '0xd0e89b2af5e4910726fbcd8b8dd37bb79b29e5f83f7491bca830e94f7f226d29::eth::ETH',
  deep: '0xdeeb7a4662eec9f2f3def03fb937a663dddaa2e215b8078a284d026b7946c270::deep::DEEP',
  fud: '0x76cb819b01abed502bee8a702b4c2d547532c12f25001c9dea795a5e631c26f1::fud::FUD',
};

export const coinMetadataIds = {
  sui: '0x9258181f5ceac8dbffb7030890243caed69a9599d2886d957a9cb7656af3bdb3',
  sca: '0x5d26a1e9a55c88147ac870bfa31b729d7f49f8804b8b3adfdf3582d301cca844',
  cetus: '0x4c0dce55eff2db5419bbd2d239d1aa22b4a400c01bbb648b058a9883989025da',
  afSui: '0x2f9217f533e51334873a39b8026a4aa6919497b47f49d0986a4f1aec66f8a34d',
  haSui: '0x2c5f33af93f6511df699aaaa5822d823aac6ed99d4a0de2a4a50b3afa0172e24',
  vSui: '0xabd84a23467b33854ab25cf862006fd97479f8f6f53e50fe732c43a274d939bd',
  wormholeUsdc: '0x4fbf84f3029bd0c0b77164b587963be957f853eccf834a67bb9ecba6ec80f189',
  wormholeUsdt: '0xfb0e3eb97dd158a5ae979dddfa24348063843c5b20eb8381dd5fa7c93699e45c',
  wormholeEth: '0x8900e4ceede3363bef086d6b50ca89d816d0e90bf6bc46efefe1f8455e08f50f',
  wormholeSol: '0x4d2c39082b4477e3e79dc4562d939147ab90c42fc5f3e4acf03b94383cd69b6e',
  wormholeApt: '0xc969c5251f372c0f34c32759f1d315cf1ea0ee5e4454b52aea08778eacfdd0a8',
  wormholeBtc: '0x5d3c6e60eeff8a05b693b481539e7847dfe33013e7070cdcb387f5c0cac05dfd',
  nativeUsdc: '0x69b7a7c3c200439c1b5f3b19d7d495d5966d5f08de66c69276152f8db3992ec6',
  sbEth: '0x89b04ba87f8832d4d76e17a1c9dce72eb3e64d372cf02012b8d2de5384faeef0',
  deep: '0x6e60b051a08fa836f5a7acd7c464c8d9825bc29c44657fe170fe9b8e1e4770c0',
  fud: '0x01087411ef48aaac1eb6e24803213e3a60a03b147dac930e5e341f17a85e524e',
};

export const coinDecimals = {
  sui: 9,
  sca: 9,
  cetus: 9,
  afSui: 9,
  haSui: 9,
  vSui: 9,
  wormholeUsdc: 6,
  wormholeUsdt: 6,
  wormholeEth: 8,
  wormholeSol: 8,
  wormholeApt: 8,
  wormholeBtc: 8,
  nativeUsdc: 6,
  sbEth: 8,
  deep: 6,
  fud: 5,
}
