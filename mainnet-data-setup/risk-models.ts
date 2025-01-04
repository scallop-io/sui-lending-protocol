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
  collateralFactor: 40,
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
  maxCollateralAmount: 3 * 10 ** (coinDecimals.wormholeEth + 3), // 3,000 ETH
}

export const wormholeUsdcRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeUsdc + 8), // 100 million USDC
}

export const wormholeUsdtRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeUsdt + 8), // 100 million USDT
}

export const scaRiskModel: RiskModel = {
  collateralFactor: 40,
  liquidationFactor: 70,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.sca + 6), // 1M SCA
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
  maxCollateralAmount: 10 ** (coinDecimals.vSui + 3), // 1k haSUI
}

export const wormholeBtcRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 2 * 10 ** (coinDecimals.wormholeBtc + 1), // 20 Btc
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
  maxCollateralAmount: 10 ** (coinDecimals.nativeUsdc + 7), // 10M USDC
}

export const sbEthRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 2 * 10 ** (coinDecimals.sbEth + 3), // 2000 ETH
}

export const fdusdRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 2 * 10 ** (coinDecimals.fdusd + 6), // 2 million FDUSD
}

export const sbUsdtRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 5 * 10 ** (coinDecimals.sbUsdt + 6), // 5 million USDT
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
}
