import { NextRequest, NextResponse } from "next/server";
import { auth } from "~/app/auth";
import { CreateQRCodeRequest } from "~/types/qr-type";
import { query } from "~/lib/db";
import QRCode from 'qrcode'
import path from 'path'
import fs from 'fs/promises'

interface PostQRResponse {
  short_code: string;
  qr_uid: string;
}


// This post request makes a new QR code into the database and returns the uid for that qr code in the database. 
export async function POST(request : NextRequest){ 
    // Checking to see if the user is signed in
    const session = await auth();
    if (!session || !session.user.id) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }
    const uid = session.user.id
    // Now we enter into the qr codxe creation 
    try {
        const body = (await request.json()) as CreateQRCodeRequest
        // Making sure all fields are met
        if (!body.url) {
          return NextResponse.json(
            { error: "UID and URL is required" },
            { status: 400 }
          )
        }     
        // Maybe consider adding some checksums for valid url to remove any tom foolery lol
        const qr_id: PostQRResponse[] = await query(
          "WITH qr AS (SELECT create_qr_code($1, $2, $3) as result) SELECT (result).short_code, (result).qr_uid FROM qr",
          [uid, body.url, "http://localhost:3000/findqr/"]
        )

        if (!qr_id[0]?.qr_uid || qr_id.length > 1 || qr_id.length <= 0 || !qr_id[0]?.short_code) {
          return NextResponse.json(
            {error: "Something went wrong with creating qr code"},
            {status: 500}
          )
        }

        console.log("RETURN ", qr_id)
        const qr_short_code = qr_id[0]?.short_code
        const qr_uid = qr_id[0]?.qr_uid
        const embedded_url = `http://localhost:3000/findqr/${qr_short_code}`
        const filepath = path.join(
          process.cwd(),
          "public",
          "qrcodes",
          qr_uid.substring(0, 2),
          qr_uid.substring(2, 4),
          `${qr_uid}.png`
        );
    
        // Create directory structure if it doesn't exist
        const dirPath = path.dirname(filepath);
        await fs.mkdir(dirPath, { recursive: true });
    
        // Generate QR code and save directly to file
        await QRCode.toFile(filepath, embedded_url, {
          width: 300,
          margin: 2,
          color: {
            dark: '#000000',
            light: '#ffffff'
          }
        });
    
        // Also generate data URL for immediate response
        const qrCodeDataURL = await QRCode.toDataURL(embedded_url, {
          width: 300,
          margin: 2,
          color: {
            dark: '#000000',
            light: '#ffffff'
          }
        });

        return NextResponse.json({
            success: true,
            qr_code: qrCodeDataURL,
            short_uid: qr_short_code
        }, {
          status: 200
        })

    } catch (error) {
        console.log("Failed to create a QR code: ", error)
        return NextResponse.json(
            {error: "Failed to create QR"},
            {status: 500}
        )
    }
}