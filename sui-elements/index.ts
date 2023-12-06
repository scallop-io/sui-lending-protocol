import dotenv from "dotenv";
import { NetworkType, SuiKit } from "@scallop-io/sui-kit";
import { SuiAdvancePackagePublisher } from "@scallop-io/sui-package-kit";

dotenv.config();

export const secretKey = process.env.SECRET_KEY || '';
export const networkType = (process.env.SUI_NETWORK_TYPE || 'testnet') as NetworkType;

const fullNode = process.env.MAINNET_FULLNODE || 'https://fullnode.mainnet.sui.io:443';
export const suiKit = new SuiKit({ secretKey, networkType, fullnodeUrls: [fullNode] });

export const packagePublisher = new SuiAdvancePackagePublisher({ networkType });
