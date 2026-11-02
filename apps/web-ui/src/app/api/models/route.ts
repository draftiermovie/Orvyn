import { NextRequest, NextResponse } from "next/server";

import { proxyUrl } from "@/lib/server-config";

export async function GET() {
  try {
    const resp = await fetch(`${await proxyUrl()}/api/models`);
    const data = await resp.json();
    return NextResponse.json(data);
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
