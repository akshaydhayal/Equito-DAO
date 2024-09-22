"use client";

import type { Metadata } from "next";
import { Inter } from "next/font/google";
import { WagmiProvider } from "wagmi";
import {
  RainbowKitProvider,
  darkTheme as rainbowDarkTheme,
} from "@rainbow-me/rainbowkit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AppRouterCacheProvider } from "@mui/material-nextjs/v14-appRouter";
import { ThemeProvider, createTheme } from "@mui/material/styles";
import CssBaseline from "@mui/material/CssBaseline";
import { wagmiConfig } from "../utils/wagmi";
import { Navbar } from "@/components/navbar";
import { EquitoVoteProvider } from "@/providers/equito-vote-provider";
import { Toast } from "@/components/toast";
import { Footer } from "@/components/footer";
import "@rainbow-me/rainbowkit/styles.css";
import "../app/globals.css";

const inter = Inter({ subsets: ["latin"] });

const queryClient = new QueryClient();

export const darkTheme = createTheme({
  palette: {
    mode: "dark",
  },
});

export const lightTheme = createTheme({
  palette: {
    mode: "light",
  },
});

export function AppLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <WagmiProvider config={wagmiConfig}>
          <QueryClientProvider client={queryClient}>
            <RainbowKitProvider theme={rainbowDarkTheme()}>
              <EquitoVoteProvider>
                <AppRouterCacheProvider>
                  <ThemeProvider theme={darkTheme}>
                    <CssBaseline />
                    <div className="flex flex-row justify-center">
                      {/* <div className="" style={{ width: "1200px" }}> */}
                      <div className="w-full bg-[#121212]">
                        <Navbar />
                        <main>{children}</main>
                      </div>
                    </div>
                    <Toast />
                  </ThemeProvider>
                </AppRouterCacheProvider>
              </EquitoVoteProvider>
            </RainbowKitProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  );
}
