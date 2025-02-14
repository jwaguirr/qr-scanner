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

        const locationData = await query(`
            SELECT 
                city, 
                lat, 
                lon,
                COUNT(*) * 100.0 / (SELECT COUNT(*) FROM qr_scans WHERE qr_uid = $1) AS percentage
            FROM qr_scans
            WHERE qr_uid = $1
            GROUP BY city, lat, lon
            ORDER BY percentage DESC
            LIMIT 10
        `, [qr_uid]);
                
        return NextResponse.json({ topCities: locationData }, { status: 200 });

    } catch (error) {
        console.error("Error fetching top locations:", error);
        return NextResponse.json({ error: "Failed to fetch top locations" }, { status: 500 });
    }
}
