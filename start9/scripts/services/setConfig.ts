import { types, YAML } from "../../deps.ts";

export const setConfig: types.ExpectedExports.setConfig = async (
  effects: types.Effects,
  // deno-lint-ignore no-explicit-any
  newConfig: any,
) => {
  // Validate: fee address required when fee > 0
  if (
    newConfig["pool-fee"] > 0 &&
    (!newConfig["pool-fee-address"] ||
      newConfig["pool-fee-address"].trim() === "")
  ) {
    return {
      error: "Pool Fee Address is required when Pool Fee is greater than 0.",
    };
  }

  await effects.createDir({
    path: "start9",
    volumeId: "main",
  });

  await effects.writeFile({
    path: "start9/config.yaml",
    toWrite: YAML.stringify(newConfig),
    volumeId: "main",
  });

  const result: types.SetResult = {
    signal: "SIGTERM",
    "depends-on": {},
  };
  return { result };
};
