import dotenv from "dotenv";
import { NetworkType, SuiKit } from "@scallop-io/sui-kit";
import { SuiAdvancePackagePublisher } from "@scallop-io/sui-package-kit";

dotenv.config();

export const secretKey = process.env.SECRET_KEY || '';
export const networkType = (process.env.SUI_NETWORK_TYPE || 'testnet') as NetworkType;
export const suiKit = new SuiKit({ secretKey, networkType });

console.log('Current address: ', suiKit.currentAddress());


export const packagePublisher = new SuiAdvancePackagePublisher({ networkType });
