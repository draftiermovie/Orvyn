import { NextRequest, NextResponse } from "next/server";

import { proxyUrl } from "@/lib/server-config";

export async function POST(request: NextRequest) {
  try {
    const formData = await request.formData();
    const resp = await fetch(`${await proxyUrl()}/api/ocr`, {
      method: "POST",
      body: formData,
    });
    const data = await resp.json();
    return NextResponse.json(data, { status: resp.status });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
