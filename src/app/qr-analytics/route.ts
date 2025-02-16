import { NextRequest, NextResponse } from "next/server";
import { query } from "~/lib/db";
import { auth } from "../auth";

export async function GET(request: NextRequest) {
  const session = await auth();
  
  if (!session || !session.user?.id) {
    // Redirect to sign-in if the user is unauthenticated
    const redirectUrl = new URL("/auth/sign-in", request.nextUrl.origin).toString();
    return NextResponse.redirect(redirectUrl);
  }

  try {
    const latestQr = await query(`
      SELECT qr_uid FROM qr_codes 
      WHERE canview = true 
      ORDER BY created_at DESC LIMIT 1
    `);

    if (latestQr.length === 0) {
      return NextResponse.json({ error: "No QR codes found" }, { status: 404 });
    }

    const latestQrId = latestQr[0].qr_uid;
    const absoluteUrl = new URL(`/qr-analytics/${latestQrId}`, request.nextUrl.origin).toString();
    return NextResponse.redirect(absoluteUrl);
  } catch (error) {
    console.error("Error fetching latest QR:", error);
    return NextResponse.json({ error: "Failed to fetch latest QR" }, { status: 500 });
  }
}