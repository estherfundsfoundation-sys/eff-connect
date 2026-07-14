import type { Metadata } from "next";
import "./globals.css";
export const metadata:Metadata={title:"EFF Connect | Membership & Community",description:"The secure membership, chapter, and community platform for Esther Funds Foundation and Pretty Girls Who Serve."};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
