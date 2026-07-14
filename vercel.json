import { createHash } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/supabase-admin";
import { jsonError } from "@/lib/http";

export async function POST(request: NextRequest) {
  const { token } = await request.json();
  if (!token) return jsonError("A claim token is required");
  const hash = createHash("sha256").update(token).digest("hex");
  const data = await db.one<Record<string,any>>("legacy_member_claims", `select=id,email,first_name,last_name,imported_profile,status,token_expires_at&token_hash=eq.${hash}`);
  if (!data) return jsonError("This claim link is invalid", 404);
  if (data.status === "claimed") return jsonError("This membership has already been claimed", 409);
  if (!data.token_expires_at || new Date(data.token_expires_at) < new Date()) {
    await db.update("legacy_member_claims", `id=eq.${data.id}`, { status: "expired" });
    return jsonError("This claim link has expired. Ask EFF staff to resend it.", 410);
  }
  await db.update("legacy_member_claims", `id=eq.${data.id}`, { status: "opened", opened_at: new Date().toISOString() });
  return NextResponse.json({ ok: true, claim: data });
}
