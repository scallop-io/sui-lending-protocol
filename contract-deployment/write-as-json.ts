import fs from 'fs';
export const writeAsJson = (obj: any, output: string) => {
  const jsonStr = JSON.stringify(obj, null, 2);
  // write to file in nodejs,
  fs.writeFileSync(output, jsonStr);
}
