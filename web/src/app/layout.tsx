import type { Metadata } from "next";
import "./globals.css";
import { ServiceWorkerRegistrar } from "@/components/ServiceWorkerRegistrar";
import { FirebaseBootstrap } from "@/components/FirebaseBootstrap";
import { ThemeBootstrap } from "@/components/ThemeBootstrap";
import { Navbar } from "@/components/Navbar";

export const metadata: Metadata = {
  title: "Sar Kyat Pro",
  description: "Daily drill in minutes",
  applicationName: "Sar Kyat Pro",
  appleWebApp: {
    capable: true,
    title: "Sar Kyat Pro",
    statusBarStyle: "black-translucent",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="bg-[#0A0B0F]">
        <ThemeBootstrap>
          <FirebaseBootstrap>
            <ServiceWorkerRegistrar />
            {children}
            <Navbar />
          </FirebaseBootstrap>
        </ThemeBootstrap>
      </body>
    </html>
  );
}
