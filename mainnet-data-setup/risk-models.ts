import { RiskModel } from '../contracts/protocol';
import {
  suiDecimal,
  wormholeEthDecimal,
  wormholeUsdcDecimal,
  wormholeUsdtDecimal
} from './chain-data';

export const suiRiskModel: RiskModel = {
  collateralFactor: 60,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (suiDecimal + 6), // 1 million SUI
};

export const wormholeEthRiskModel: RiskModel = {
  collateralFactor: 70,
  liquidationFactor: 80,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (wormholeEthDecimal + 4), // 10,000 ETH
}

export const wormholeUsdcRiskModel: RiskModel = {
  collateralFactor: 80,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (wormholeUsdcDecimal + 6), // 1 million USDC
}

export const wormholeUsdtRiskModel: RiskModel = {
  collateralFactor: 80,
  liquidationFactor: 90,
  liquidationPanelty: 5,
  liquidationDiscount: 4,
  scale: 100,
  maxCollateralAmount: 10 ** (wormholeUsdtDecimal + 6), // 1 million USDT
}


export const riskModels = {
  sui: suiRiskModel,
  wormholeEth: wormholeEthRiskModel,
  wormholeUsdc: wormholeUsdcRiskModel,
  wormholeUsdt: wormholeUsdtRiskModel,
}
