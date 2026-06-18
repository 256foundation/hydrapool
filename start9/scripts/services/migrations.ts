import { compat, types } from "../../deps.ts";

export const migration: types.ExpectedExports.migration =
  compat.migrations.fromMapping({}, "2.4.0");
