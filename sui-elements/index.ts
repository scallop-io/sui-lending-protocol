import dotenv from "dotenv";
import { NetworkType, SuiKit } from "@scallop-io/sui-kit";
import { SuiAdvancePackagePublisher } from "@scallop-io/sui-package-kit";

dotenv.config();

export const secretKey = process.env.SECRET_KEY || '';
export const networkType = (process.env.SUI_NETWORK_TYPE || 'testnet') as NetworkType;

const shinamiNode = 'https://api.shinami.com/node/v1/sui_mainnet_5107e0492f9ce6b16da708ca72aafc2c';
export const suiKit = new SuiKit({ secretKey, networkType, fullnodeUrls: [shinamiNode] });

export const packagePublisher = new SuiAdvancePackagePublisher({ networkType });
