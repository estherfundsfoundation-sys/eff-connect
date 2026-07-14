import { NextResponse } from "next/server";
import { db } from "@/lib/supabase-admin";

const escape = (value: unknown) => `"${String(value ?? "").replaceAll('"', '""')}"`;

export async function GET() {
  const data = await db.list<Record<string,unknown>>("legacy_member_claims", "select=email,first_name,last_name,status,sent_at,opened_at,token_expires_at,last_error,resend_count&status=neq.claimed&order=created_at.asc");
  const columns = ["email","first_name","last_name","status","sent_at","opened_at","token_expires_at","last_error","resend_count"];
  const csv = [columns.join(","), ...data.map((row:Record<string,unknown>) => columns.map(key => escape(row[key])).join(","))].join("\r\n");
  return new NextResponse(csv, { headers: { "Content-Type": "text/csv; charset=utf-8", "Content-Disposition": `attachment; filename="eff-connect-unclaimed-members-${new Date().toISOString().slice(0,10)}.csv"` } });
}
