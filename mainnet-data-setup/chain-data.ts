
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
  | 'fdusd'
  | 'sbUsdt'
  | 'sbwBTC'
  | 'usdy'
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
  | 'fdusd'
  | 'sbUsdt'
  | 'blub'
  | 'sbwBTC'
  | 'mUsd'
  | 'ns'
  | 'usdy'
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
  fdusd: '0xf16e6b723f242ec745dfd7634ad072c42d5c1d9ac9d62a39c381303eaa57693a::fdusd::FDUSD',
  sbUsdt: '0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT',
  blub: '0xfa7ac3951fdca92c5200d468d31a365eb03b2be9936fde615e69f0c1274ad3a0::BLUB::BLUB',
  sbwBTC: '0xaafb102dd0902f5055cadecd687fb5b71ca82ef0e0285d90afde828ec58ca96b::btc::BTC',
  mUsd: '0xe44df51c0b21a27ab915fa1fe2ca610cd3eaa6d9666fe5e62b988bf7f0bd8722::musd::MUSD',
  ns: '0x5145494a5f5100e645e4b0aa950fa6b68f614e8c59e17bc5ded3495123a79178::ns::NS',
  usdy: '0x960b531667636f39e85867775f52f6b1f220a058c4de786905bdf761e06a56bb::usdy::USDY',
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
  fdusd: '0xdebee5265a67c186ed87fe93303d33dfe1de53e3b4fd7d9329c2852860acd3e7',
  sbUsdt: '0xda61b33ac61ed4c084bbda65a2229459ed4eb2185729e70498538f0688bec3cc',
  blub: '0xac32b519790cae96c3317457d903d61d04f1bc8f7710096d80fcba72c7a53703',
  sbwBTC: '0x53e1cae1ad70a778d0b450d36c7c2553314ca029919005aad26945d65a8fb784',
  mUsd: '0xc154abd271b24032a2c80d96c1b82109490bb600ed189ef881d8c9467ed44a4f',
  ns: '0x279adec041f8ec5c2d419abf2c32713ae7930a9a3a1ff244c88e5ceced40db6e',
  usdy: '0xd8dd6cf839e2367de6e6107da4b4361f44798dd6cf26d094058d94e4cee25e36',
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
  fdusd: 6,
  sbUsdt: 6,
  blub: 2,
  sbwBTC: 8,
  mUsd: 9,
  ns: 6,
  usdy: 6,
}
