import dotenv from "dotenv";
import { NetworkType, SuiKit } from "@scallop-io/sui-kit";
import { SuiAdvancePackagePublisher } from "@scallop-io/sui-package-kit";

dotenv.config();

export const secretKey = process.env.SECRET_KEY || '';
export const networkType = (process.env.SUI_NETWORK_TYPE || 'testnet') as NetworkType;

const fullNode = 'https://api.shinami.com/node/v1/sui_mainnet_8a6507ca04e7ba4cdc713a9d66e9d54a';

export const suiKit = new SuiKit({ secretKey, networkType, fullnodeUrls: [fullNode] });

console.log(networkType);
console.log(suiKit.currentAddress());

export const packagePublisher = new SuiAdvancePackagePublisher({ networkType });
