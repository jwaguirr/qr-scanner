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

        const scanTrends = await query(`
            SELECT 
                TO_CHAR(scanned_at, 'YYYY-MM-DD') AS scan_date, 
                COUNT(*) AS total_scans
            FROM qr_scans
            WHERE qr_uid = $1
            GROUP BY scan_date
            ORDER BY scan_date ASC
        `, [qr_uid]);

        return NextResponse.json({ scanTrends }, { status: 200 });

    } catch (error) {
        console.error("Error fetching scan trends:", error);
        return NextResponse.json({ error: "Failed to fetch scan trends" }, { status: 500 });
    }
}
