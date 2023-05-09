import * as fs from 'fs';
import * as toml from '@iarna/toml';

type MoveToml = {
  package: Record<string, any>;
  dependencies: Record<string, any>;
  addresses: Record<string, any>;
  ['devnet-addresses']?: Record<string, any>;
  ['testnet-addresses']?: Record<string, any>;
  ['mainnet-addresses']?: Record<string, any>;
  ['localhost-addresses']?: Record<string, any>;
}

export const parseMoveToml = (tomlPath: string) => {
  // Read the TOML file
  const tomlStr = fs.readFileSync(tomlPath, 'utf8');
  // Parse the TOML file
  const parsedToml = toml.parse(tomlStr);
  return parsedToml as MoveToml;
}

export const writeMoveToml = (tomlContent: MoveToml, outPath: string) => {
  let tomlFileContent = toml.stringify(tomlContent);
  fs.writeFileSync(outPath, tomlFileContent);
}
