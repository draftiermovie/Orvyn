import { NextRequest, NextResponse } from "next/server";

import { proxyUrl } from "@/lib/server-config";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const resp = await fetch(`${await proxyUrl()}/v1/chat/completions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const data = await resp.json();
    return NextResponse.json(data, { status: resp.status });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
