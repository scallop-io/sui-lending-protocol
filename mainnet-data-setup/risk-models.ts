import { RiskModel } from '../contracts/protocol';
import {
  SupportedCollaterals,
  coinDecimals,
} from './chain-data';

export const suiRiskModel: RiskModel = {
  collateralFactor: 75,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 20_000_000 * 10 ** (coinDecimals.sui), // 20 million SUI
};

export const cetusRiskModel: RiskModel = {
  collateralFactor: 50,
  liquidationFactor: 80,
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
  maxCollateralAmount: 10 ** (coinDecimals.wormholeEth + 4), // 10,000 ETH
}

export const wormholeUsdcRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeUsdc + 7), // 10 million USDC
}

export const wormholeUsdtRiskModel: RiskModel = {
  collateralFactor: 85,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeUsdt + 7), // 10 million USDT
}

export const scaRiskModel: RiskModel = {
  collateralFactor: 50,
  liquidationFactor: 70,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.sca + 5), // 100k SCA
}

export const afSuiRiskModel: RiskModel = {
  collateralFactor: 70,
  liquidationFactor: 75,
  liquidationPanelty: 10,
  liquidationDiscount: 8,
  scale: 100,
  maxCollateralAmount: 2_000_000 * (10 ** coinDecimals.afSui), // 2 million afSUI
}

export const haSuiRiskModel: RiskModel = {
  collateralFactor: 70,
  liquidationFactor: 75,
  liquidationPanelty: 10,
  liquidationDiscount: 8,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.haSui + 5), // 100k haSUI
}

export const vSuiRiskModel: RiskModel = {
  collateralFactor: 60,
  liquidationFactor: 70,
  liquidationPanelty: 10,
  liquidationDiscount: 8,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.vSui + 3), // 1k haSUI
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
}
