import { RiskModel } from '../contracts/protocol';
import {
  SupportedCollaterals,
  coinDecimals,
} from './chain-data';

export const suiRiskModel: RiskModel = {
  collateralFactor: 60,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.sui + 7), // 10 million SUI
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

export const wormholeBtcRiskModel: RiskModel = {
  collateralFactor: 0,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeBtc + 3), // 1,000 BTC
}

export const wormholeSolRiskModel: RiskModel = {
  collateralFactor: 0,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeSol + 4), // 10,000 SOL
}

export const wormholeAptRiskModel: RiskModel = {
  collateralFactor: 0,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (coinDecimals.wormholeApt + 5), // 100,000 APT
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


export const riskModels: Record<SupportedCollaterals, RiskModel> = {
  sui: suiRiskModel,
  cetus: cetusRiskModel,
  wormholeEth: wormholeEthRiskModel,
  wormholeUsdc: wormholeUsdcRiskModel,
  wormholeUsdt: wormholeUsdtRiskModel,
  wormholeBtc: wormholeBtcRiskModel,
  wormholeSol: wormholeSolRiskModel,
  wormholeApt: wormholeAptRiskModel,
}
