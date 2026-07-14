import { createHash, randomBytes } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/supabase-admin";
import { jsonError, requireEnv } from "@/lib/http";

export async function POST(request: NextRequest) {
  try {
    requireEnv("RESEND_API_KEY", "RESEND_FROM_EMAIL", "APP_URL");
    const { claimId } = await request.json();
    if (!claimId) return jsonError("claimId is required");
    const claim = await db.one<Record<string, any>>("legacy_member_claims", `select=*&id=eq.${encodeURIComponent(claimId)}`);
    if (!claim) return jsonError("Legacy member claim was not found", 404);
    if (claim.status === "claimed" || claim.status === "cancelled") return jsonError("This claim cannot be resent", 409);

    const token = randomBytes(32).toString("base64url");
    const tokenHash = createHash("sha256").update(token).digest("hex");
    const expires = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const claimUrl = `${process.env.APP_URL}/claim?token=${encodeURIComponent(token)}`;
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        from: process.env.RESEND_FROM_EMAIL,
        to: [claim.email],
        subject: "Claim your new EFF Connect member profile",
        html: `<h1>Welcome to EFF Connect</h1><p>Hi ${claim.first_name || "there"},</p><p>We imported your existing membership record. Use this secure link to review your information, complete missing profile details, choose privacy and communication preferences, and activate your new account without creating a duplicate membership.</p><p><a href="${claimUrl}">Claim my EFF Connect profile</a></p><p>This private link expires in 7 days.</p>`,
      }),
    });
    const provider = await response.json();
    if (!response.ok) return jsonError(provider.message || "Email provider rejected the message", 502);
    await db.update("legacy_member_claims", `id=eq.${encodeURIComponent(claimId)}`, { token_hash: tokenHash, token_expires_at: expires, status: "sent", sent_at: new Date().toISOString(), resend_count: Number(claim.resend_count || 0) + 1, last_error: null });
    await db.insert("audit_events", { action: "legacy_claim.sent", entity_type: "legacy_member_claim", entity_id: claimId, metadata: { provider_message_id: provider.id } });
    return NextResponse.json({ ok: true, expiresAt: expires });
  } catch (error) {
    return jsonError(error instanceof Error ? error.message : "Unable to send claim invitation", 500);
  }
}
