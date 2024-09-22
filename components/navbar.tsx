"use client";

import Link from "next/link";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export function Navbar() {
  return (
    <nav className="h-[10vh] border-b border-b-slate-500 px-10">
      {/* <ul className="flex lg:flex-row flex-col lg:items-center mt-6 mb-8 justify-center"> */}
      <ul className="flex lg:flex-row flex-col lg:items-center py-2 justify-center">
        <div className="flex flex-row flex-wrap mb-8 lg:mb-0 gap-y-6">
          <li className="mr-12 hover-glow">
            <Link href="/">PROPOSALS</Link>
          </li>
          <li className="mr-12 hover-glow">
            <Link href="/create">CREATE</Link>
          </li>
          <li className="mr-12 hover-glow">
            <Link href="/add-new-token">ADD TOKEN</Link>
          </li>
          <li className="hover-glow">
            <Link href="/faucet">FAUCET</Link>
          </li>
        </div>
        <li className="lg:ml-auto ">
          <ConnectButton
            chainStatus="full"
            showBalance={false}
            accountStatus={{
              smallScreen: "avatar",
              largeScreen: "full",
            }}
          />
        </li>
      </ul>
    </nav>
  );
}
