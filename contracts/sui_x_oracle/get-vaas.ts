/// Fetch price feed VAAs of interest from the Pyth
/// price feed service.
import { PriceServiceConnection } from "@pythnetwork/price-service-client";

export const getVaas = async (priceIds: string[]) => {
  const connection = new PriceServiceConnection(
    "https://xc-testnet.pyth.network",
    {
      priceFeedRequestConfig: {
        binary: true,
      },
    }
  );
  return await connection.getLatestVaas(priceIds);
}
