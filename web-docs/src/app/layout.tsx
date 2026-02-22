import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "StillMe - Legal Documents",
  description: "Terms of Service and Privacy Policy for StillMe app.",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ja">
      <body className={`${inter.className} bg-black text-white`}>
        <main className="min-h-screen">
          {children}
        </main>
      </body>
    </html>
  );
}
