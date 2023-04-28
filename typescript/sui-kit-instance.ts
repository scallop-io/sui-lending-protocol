import dotenv from "dotenv";
import { NetworkType, SuiKit } from "@scallop-dao/sui-kit";

dotenv.config();

export const secretKey = process.env.SECRET_KEY || '';
export const networkType = (process.env.SUI_NETWORK_TYPE || 'devnet') as NetworkType;
export const suiKit = new SuiKit({ secretKey, networkType });
