import { NextRequest, NextResponse } from "next/server";
import { jsonError, requireEnv } from "@/lib/http";

const allowedProducts: Record<string, string | undefined> = {
  "pgws-lifetime": process.env.STRIPE_PGWS_LIFETIME_PRICE_ID,
  "executive-board-commitment": process.env.STRIPE_EXECUTIVE_BOARD_PRICE_ID,
};

export async function POST(request: NextRequest) {
  try {
    requireEnv("STRIPE_SECRET_KEY", "APP_URL");
    const { product, email, profileId } = await request.json();
    const price = allowedProducts[product];
    if (!price) return jsonError("Unknown or unconfigured product");
    const body = new URLSearchParams({ mode: "payment", "line_items[0][price]": price, "line_items[0][quantity]": "1", success_url: `${process.env.APP_URL}/memberships?payment=success`, cancel_url: `${process.env.APP_URL}/memberships?payment=cancelled`, "metadata[product]": product, "metadata[profile_id]": profileId || "" });
    if (email) body.set("customer_email", email);
    const response = await fetch("https://api.stripe.com/v1/checkout/sessions", { method: "POST", headers: { Authorization: `Bearer ${process.env.STRIPE_SECRET_KEY}`, "Content-Type": "application/x-www-form-urlencoded" }, body });
    const session = await response.json();
    if (!response.ok) return jsonError(session.error?.message || "Stripe checkout could not be created", 502);
    return NextResponse.json({ ok: true, url: session.url });
  } catch (error) { return jsonError(error instanceof Error ? error.message : "Checkout unavailable", 500); }
}
