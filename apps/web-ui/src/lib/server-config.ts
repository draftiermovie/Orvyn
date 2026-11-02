import { readFile } from "node:fs/promises";
import path from "node:path";

export async function serverConfig() {
  const file = process.env.AI_USB_CONFIG || path.resolve(process.cwd(), "../config/settings.json");
  return JSON.parse(await readFile(file, "utf8"));
}

export async function proxyUrl() {
  const cfg = await serverConfig();
  return `http://127.0.0.1:${cfg.services.proxy.port}`;
}
