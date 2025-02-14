import { NextRequest, NextResponse } from "next/server";
import { auth } from "~/app/auth";
import { query } from "~/lib/db";

export async function GET(request: NextRequest) {
    const session = await auth();
    if (!session || !session.user.id) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    try {
        const { searchParams } = new URL(request.url);
        const qr_uid = searchParams.get("qr_uid");

        if (!qr_uid) {
            return NextResponse.json({ error: "QR UID is required" }, { status: 400 });
        }

        const osData = await query(`
            SELECT 
                COALESCE(os, 'Unknown') AS os, 
                COUNT(*) * 100.0 / (SELECT COUNT(*) FROM qr_scans WHERE qr_uid = $1) AS percentage
            FROM qr_scans
            WHERE qr_uid = $1
            GROUP BY os
            ORDER BY percentage DESC
        `, [qr_uid]);

        return NextResponse.json({ osBreakdown: osData }, { status: 200 });

    } catch (error) {
        console.error("Error fetching OS breakdown:", error);
        return NextResponse.json({ error: "Failed to fetch OS breakdown" }, { status: 500 });
    }
}
