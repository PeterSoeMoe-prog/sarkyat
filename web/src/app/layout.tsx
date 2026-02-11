import type { Metadata } from "next";
import "./globals.css";
import { ServiceWorkerRegistrar } from "@/components/ServiceWorkerRegistrar";
import { FirebaseBootstrap } from "@/components/FirebaseBootstrap";
import { ThemeBootstrap } from "@/components/ThemeBootstrap";
import { Navbar } from "@/components/Navbar";
import { InstallPrompt } from "@/components/InstallPrompt";
import { AntiZoom } from "@/components/AntiZoom";

export const metadata: Metadata = {
  title: "Sar Kyat Pro",
  description: "Daily drill in minutes",
  applicationName: "Sar Kyat Pro",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    title: "Sar Kyat Pro",
    statusBarStyle: "black-translucent",
    startupImage: [
      {
        url: "/icon-1024.png",
        media: "(device-width: 320px) and (device-height: 568px) and (-webkit-device-pixel-ratio: 2)",
      },
    ],
  },
  other: {
    "mobile-web-app-capable": "yes",
    "apple-mobile-web-app-capable": "yes",
    "apple-mobile-web-app-status-bar-style": "black-translucent",
    "apple-mobile-web-app-title": "Sar Kyat Pro",
    "theme-color": "#0A0B0F",
    "viewport": "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"
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
            <AntiZoom />
            <ServiceWorkerRegistrar />
            <InstallPrompt />
            {children}
            <Navbar />
          </FirebaseBootstrap>
        </ThemeBootstrap>
      </body>
    </html>
  );
}
