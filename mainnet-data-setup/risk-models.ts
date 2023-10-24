import { RiskModel } from '../contracts/protocol';
import {
  SupportedCollaterals,
  coinDecimals,
} from './chain-data';

export const suiRiskModel: RiskModel = {
  collateralFactor: 70,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 20_000_000 * 10 ** (coinDecimals.sui), // 20 million SUI
};

export const cetusRiskModel: RiskModel = {
  collateralFactor: 30,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.cetus + 6), // 1 million CETUS
}

export const wormholeEthRiskModel: RiskModel = {
  collateralFactor: 70,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeEth + 4), // 10,000 ETH
}

export const wormholeUsdcRiskModel: RiskModel = {
  collateralFactor: 80,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeUsdc + 7), // 10 million USDC
}

export const wormholeUsdtRiskModel: RiskModel = {
  collateralFactor: 80,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeUsdt + 7), // 10 million USDT
}

export const afSuiRiskModel: RiskModel = {
  collateralFactor: 60,
  liquidationFactor: 70,
  liquidationPanelty: 10,
  liquidationDiscount: 8,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.sui + 3), // 1k afSUI
}

export const haSuiRiskModel: RiskModel = {
  collateralFactor: 60,
  liquidationFactor: 70,
  liquidationPanelty: 10,
  liquidationDiscount: 8,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.sui + 3), // 1k haSUI
}

export const riskModels: Record<SupportedCollaterals, RiskModel> = {
  sui: suiRiskModel,
  cetus: cetusRiskModel,
  afSui: afSuiRiskModel,
  haSui: haSuiRiskModel,
  wormholeEth: wormholeEthRiskModel,
  wormholeUsdc: wormholeUsdcRiskModel,
  wormholeUsdt: wormholeUsdtRiskModel,
}
