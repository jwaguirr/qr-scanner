"use client"
import React, {useState, useEffect} from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { getSession, useSession } from 'next-auth/react'
import { QRResponse } from '~/types/qr-type'


type CreateQRInput = {
  url: string;
}


type DeleteQRInput = {
  qr_uid: string;
}

function Dashboard() {
  const queryClient = useQueryClient()
  const [customURL, setCustomURL] = useState("")


  const createQR = async (my_url: CreateQRInput) => {
    try {
      const session = await getSession();
      if (!session) throw new Error("No active session");  
      const returned = await fetch("http://localhost:3000/api/qr/create-qr", {
        method: "POST",
        body: JSON.stringify({ url: my_url.url })
      });
  
      if (!returned.ok) {
        throw new Error(`HTTP error! status: ${returned.status}`);
      }
  
      return await returned.json();
    } catch (error) {
      console.error("Error occurred:", error);
      throw error;
    }
  };
  

  const deleteQR = async (qr_uid: DeleteQRInput) => {
    try {
      const session = await getSession();
      if (!session) throw new Error("No active session");  
      const returned = await fetch("http://localhost:3000/api/qr/remove-qr", {
        method: "POST",
        body: JSON.stringify({ qr_uid :  qr_uid.qr_uid})
      });
  
      if (!returned.ok) {
        throw new Error(`HTTP error! status: ${returned.status}`);
      }
  
      return await returned.json();
    } catch (error) {
      console.error("Error occurred:", error);
      throw error;
    }
  }


  const fetchQR = async () => {
     try {
        const response = await fetch("http://localhost:3000/api/qr/pull-qr", {
          method: "GET",
        })
        if (!response.ok) {
          throw new Error(`Response status: ${response.status}`);
        }
        const data = await response.json()
        return data
    } catch (error) {
      console.error("Error occured: ", error)
    }
  }

  const {data: qrs} = useQuery<QRResponse, Error>({queryKey: ["fetch-qrs"], queryFn: fetchQR})

  const createNewQrMutation = useMutation({
    mutationFn:  (input: CreateQRInput) => createQR(input),
    onSuccess: () => {
      queryClient.invalidateQueries({queryKey: ["fetch-qrs"]})
    }
  })

  const deleteQRMutation = useMutation({
    mutationFn:  (input: DeleteQRInput) => deleteQR(input),
    onSuccess: () => {
      queryClient.invalidateQueries({queryKey: ["fetch-qrs"]})
    }
  })

  return (
    <>
      <div>My QR Codes</div>
      <div>Create new QR code</div>
      <input onChange={(e) => setCustomURL(e.target.value)}/>
      <button 
          onClick={() => createNewQrMutation.mutate({ url: customURL })}
          disabled={createNewQrMutation.isLoading}
        >
          {createNewQrMutation.isLoading ? 'Creating...' : 'Create QR'}
        </button>
      {qrs && qrs.qrCodes.map((elem, idx) => (
        <div key={idx} className='flex flex-row'>
          QR ID: {elem.qr_uid}
          <button onClick={() => deleteQRMutation.mutate({qr_uid: elem.qr_uid})}>Delete me :/</button>
        </div>
      ))}
    </>
  )
}

export default Dashboard