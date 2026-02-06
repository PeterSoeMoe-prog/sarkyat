import "./globals.css";
import { BottomNav } from "@/components/BottomNav";

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="bg-[#0A0B0F]">
        {children}
        <BottomNav />
      </body>
    </html>
  );
}
