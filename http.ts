import { NextResponse } from "next/server";

export const jsonError = (message: string, status = 400) =>
  NextResponse.json({ ok: false, error: message }, { status });

export const requireEnv = (...names: string[]) => {
  const missing = names.filter((name) => !process.env[name]);
  if (missing.length) throw new Error(`Missing server configuration: ${missing.join(", ")}`);
};
