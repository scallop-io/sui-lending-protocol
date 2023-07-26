import dotenv from "dotenv";
import { NetworkType, SuiKit } from "@scallop-io/sui-kit";
import { SuiAdvancePackagePublisher } from "@scallop-io/sui-package-kit";

dotenv.config();

export const secretKey = process.env.SECRET_KEY || '';

const shinamiNode = 'https://api.shinami.com/node/v1/sui_mainnet_af69715eb5088e2eb2000069999a65d8';
export const networkType = (process.env.SUI_NETWORK_TYPE || 'testnet') as NetworkType;
export const suiKit = new SuiKit({ secretKey, networkType, fullnodeUrls: [shinamiNode] });

export const packagePublisher = new SuiAdvancePackagePublisher({ networkType });
