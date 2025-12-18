import { RiskModel } from '../contracts/protocol';
import {
  SupportedCollaterals,
  coinDecimals,
} from './chain-data';

export const suiRiskModel: RiskModel = {
  collateralFactor: 80,
  liquidationFactor: 85,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.sui + 8), // 100 million SUI
};

export const cetusRiskModel: RiskModel = {
  collateralFactor: 0,
  liquidationFactor: 65,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.cetus + 6), // 1 million CETUS
}

export const wormholeEthRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 0 * 10 ** (coinDecimals.wormholeEth), // 0 ETH
}

export const wormholeUsdcRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 0 * 10 ** (coinDecimals.wormholeUsdc), // 0 USDC
}

export const wormholeUsdtRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 0 * 10 ** (coinDecimals.wormholeUsdt), // 0 USDT
}

export const scaRiskModel: RiskModel = {
  collateralFactor: 50,
  liquidationFactor: 70,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 2.5 * 10 ** (coinDecimals.sca + 6), // 2.5M SCA
}

export const afSuiRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 2 * 10 ** (coinDecimals.afSui + 7), // 20 million afSUI
}

export const haSuiRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 2 * 10 ** (coinDecimals.haSui + 7), // 20 million haSUI
}

export const vSuiRiskModel: RiskModel = {
  collateralFactor: 60,
  liquidationFactor: 70,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 0,
}

export const wormholeBtcRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 0 * 10 ** (coinDecimals.wormholeBtc), // 0 Btc
}

export const sbwBtcRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 50 * 10 ** (coinDecimals.sbwBTC), // 50 BTC
}

export const wormholeSolRiskModel: RiskModel = {
  collateralFactor: 70,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeSol + 4), // 10k Sol
}

export const nativeUsdcRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 3 * 10 ** (coinDecimals.nativeUsdc + 7), // 30M USDC
}

export const sbEthRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 5 * 10 ** (coinDecimals.sbEth + 3), // 5000 ETH
}

export const fdusdRiskModel: RiskModel = {
  collateralFactor: 850, // 85% 
  liquidationFactor: 900, // 90%
  liquidationPanelty: 20, // 2%
  liquidationDiscount: 19, // 1.9%
  scale: 1000,
  maxCollateralAmount: 2.5 * 10 ** (coinDecimals.fdusd + 6), // 2.5 million FDUSD
}

export const sbUsdtRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 20 * 10 ** (coinDecimals.sbUsdt + 6), // 20 million USDT
}

export const usdyRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 * 10 ** (coinDecimals.usdy + 6), // 10 million USDY
}

export const deepRiskModel: RiskModel = {
  collateralFactor: 40,
  liquidationFactor: 70,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 25 * 10 ** (coinDecimals.deep + 6), // 25M DEEP
}

export const walRiskModel: RiskModel = {
  collateralFactor: 40,
  liquidationFactor: 70,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 * 10 ** (coinDecimals.wal + 6), // 10M DEEP
}

export const xBtcRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 3,
  liquidationDiscount: 2,
  scale: 100,
  maxCollateralAmount: 10 * 10 ** (coinDecimals.xBTC), // 10 xBTC
}

export const riskModels: Record<SupportedCollaterals, RiskModel> = {
  sui: suiRiskModel,
  sca: scaRiskModel,
  cetus: cetusRiskModel,
  afSui: afSuiRiskModel,
  haSui: haSuiRiskModel,
  vSui: vSuiRiskModel,
  wormholeEth: wormholeEthRiskModel,
  wormholeUsdc: wormholeUsdcRiskModel,
  wormholeUsdt: wormholeUsdtRiskModel,
  wormholeBtc: wormholeBtcRiskModel,
  wormholeSol: wormholeSolRiskModel,
  nativeUsdc: nativeUsdcRiskModel,
  sbEth: sbEthRiskModel,
  fdusd: fdusdRiskModel,
  sbUsdt: sbUsdtRiskModel,
  sbwBTC: sbwBtcRiskModel,
  xBTC: xBtcRiskModel,
  usdy: usdyRiskModel,
  wal: walRiskModel,
  deep: deepRiskModel,
}
