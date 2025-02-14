'use client'
import React, { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { useQuery } from '@tanstack/react-query'

const Page = () => {
  const fetchQR = async () => {
    try {
      const response = await fetch(`/api/qr/pull-qr`, {
        method: "GET",
      })
      if (!response.ok) {
        throw new Error(`Response status: ${response.status}`);
      }
      const data = await response.json()
      return data
    } catch (error) {
      console.error("Error occurred: ", error)
    }
  }

  const { data: qrs } = useQuery({
    queryKey: ["fetch-qrs"],
    queryFn: fetchQR
  })

  return (
    <div className="flex min-h-screen">
      {/* Sidebar */}
      <motion.div
        initial={{ x: -300 }}
        animate={{ x: 0 }}
        className="w-64 bg-blue-800 text-white p-6 space-y-4"
      >
        <h2 className="text-xl font-bold mb-4">Your QR Codes</h2>
        <div className="space-y-2">
          {qrs && qrs.qrCodes.map((qr, idx) => (
            <motion.div
              key={qr.qr_uid}
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: idx * 0.1 }}
              className="p-3 bg-blue-700 rounded-lg hover:bg-blue-600 cursor-pointer"
            >
              <p className="text-sm truncate">{qr.embedded_link}</p>
              <img src={qr.filepath} alt="QR Code" className="w-full mt-2 rounded" />
            </motion.div>
          ))}
        </div>
      </motion.div>

      {/* Main Content */}
      <div className="flex-1 bg-gradient-to-br from-blue-400 to-blue-600 p-8">
        <motion.div 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-white rounded-xl shadow-2xl p-6"
        >
          <motion.h1 
            className="text-3xl font-bold text-blue-600 mb-6"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2 }}
          >
            Dashboard
          </motion.h1>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {[1, 2, 3].map((item) => (
              <motion.div
                key={item}
                initial={{ scale: 0.8, opacity: 0 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ delay: item * 0.1 }}
                className="bg-blue-50 p-6 rounded-lg shadow-md hover:shadow-xl transition-shadow"
              >
                <h2 className="text-xl font-semibold text-blue-800 mb-3">Card {item}</h2>
                <p className="text-blue-600">This is a cool animated card with hover effects!</p>
              </motion.div>
            ))}
          </div>
        </motion.div>
      </div>
    </div>
  )
}

export default Page