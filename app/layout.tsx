import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata={title:'WhatBot Ghana | Multi-Vendor Marketplace',description:'Shop trusted Ghanaian stores and imported deals with secure checkout.',metadataBase:new URL(process.env.NEXT_PUBLIC_APP_URL||'http://localhost:3000')};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}