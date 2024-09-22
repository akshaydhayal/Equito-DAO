"use client";

import Link from "next/link";
import { ChangeEvent, useMemo, useState } from "react";
import { useReadContract } from "wagmi";
import {
  formatProposals,
  formatTimestamp,
  isValidData,
  PAGINATION_SIZE,
  rearrangeChains,
  verifyIsProposalActive,
} from "@/utils/helpers";
import { FormattedProposal, ProposalResponse } from "@/types";
import equitoVote from "@/out/EquitoVote.sol/EquitoVote.json";
import { useEquitoVote } from "@/providers/equito-vote-provider";
import { supportedChains, supportedChainsMapBySelector } from "@/utils/chains";
import { Pagination } from "@mui/material";
import { ProposalsSkeleton } from "@/components/proposals-skeleton";
import { cn } from "@/utils/cn";

const equitoVoteAbi = equitoVote.abi;

function buildProposalRetrievalArgs(
  pageNumber: number,
  proposalsLength: number | undefined,
) {
  if (!proposalsLength) {
    return [0, 0];
  }
  const proposalLastIndex = proposalsLength - 1;
  const pageNumberZeroIndexed = pageNumber - 1;
  const start = proposalLastIndex - pageNumberZeroIndexed * PAGINATION_SIZE;
  const end = start - PAGINATION_SIZE;
  return end < -1 ? [start, -1] : [start, end];
}

function getPaginationCount(proposalsLength: number | undefined) {
  if (!proposalsLength) {
    return 1;
  }
  return Math.ceil(proposalsLength / PAGINATION_SIZE);
}

export default function HomePage() {
  const [pageNumber, setPageNumber] = useState(1);

  const { destinationChain } = useEquitoVote();

  const { data: proposalsLengthData } = useReadContract({
    address: destinationChain.equitoVoteContract,
    abi: equitoVoteAbi,
    functionName: "getProposalIdsLength",
    chainId: destinationChain.definition.id,
  });
  const proposalsLength = proposalsLengthData as bigint | undefined;
  const proposalsLengthNumber = !!proposalsLength
    ? Number(proposalsLength)
    : undefined;

  const {
    data: proposals,
    isPending: isPendingProposals,
    isError: isErrorFetchingProposals,
    error: errorFetchingProposals,
    refetch: refetchProposals,
    isRefetching: isRefetchingProposals,
    isRefetchError: isErrorRefetchingProposals,
  } = useReadContract({
    address: destinationChain.equitoVoteContract,
    abi: equitoVoteAbi,
    functionName: "getSlicedReversedProposals",
    args: buildProposalRetrievalArgs(pageNumber, proposalsLengthNumber),
    // functionName: "getSlicedReversedProposals",
    // args: [0, 0],
    // functionName: "getProposalsSlice",
    // args: [0, 1],
    query: { enabled: isValidData(proposalsLength) },
    chainId: destinationChain.definition.id,
  });

  const normalizedProposals = useMemo(
    () => formatProposals(proposals as ProposalResponse[]),
    [proposals],
  );

  console.log('propo len : ',proposalsLength);
  console.log('propo data : ',normalizedProposals);
  console.log('propo dataa : ',proposals);

  const onChangePageNumber = (event: ChangeEvent<unknown>, value: number) => {
    setPageNumber(value);
    refetchProposals();
  };

  if (isErrorFetchingProposals || isErrorRefetchingProposals) {
    console.error(errorFetchingProposals);
    return <div>Error occurred fetching proposals</div>;
  }

  if (isPendingProposals || isRefetchingProposals) {
    return <ProposalsSkeleton />;
  }

  if (!normalizedProposals.length) {
    return <div>No proposal available</div>;
  }

  return (
    <div className="h-[90vh] bg-[#121212] flex flex-col items-center">
      <div className="relative w-full h-32 rounded-b-lg shadow-lg">
        <img
          src="/meta.png"
          alt="DAO Banner"
          className="object-cover w-full h-full"
        />
        <div className="absolute inset-0 bg-black opacity-60"></div>
        <div className="absolute inset-0 flex flex-col items-center justify-center px-6 text-center">
          <h1 className="text-4xl font-serif tracking-wide font-bold text-blue-400 drop-shadow-lg transform transition duration-500 hover:scale-105">
            Equito DAO
          </h1>
          {/* <h1 className="text-6xl font-mono tracking-wide font-bold text-blue-300">{daoName}</h1> */}
          <p className="text-lg mt-5 text-slate-300">
            Empower Your Voice: Propose your Ideas and Vote on Other Proposals
          </p>
        </div>
      </div>
      <div className="w-[80vw] pt-8 overflow-scroll ">
        <ul className="px-8">
          {normalizedProposals.map((item) => {
            const isActive = verifyIsProposalActive(item as FormattedProposal);
            const originChainImg =
              supportedChainsMapBySelector[item.originChainSelector]?.img;
            const startDate = formatTimestamp(item.startTimestamp);
            const endDate = formatTimestamp(item.endTimestamp);
            // Rendering origin chain as the first one available.
            // Should not result in a performance hit since there can be
            // only `PAGINATION_SIZE` items at a time and ~20 chains
            // maximum for each item.
            const rearrangedSupportedChains = rearrangeChains(
              supportedChains,
              item.originChainSelector,
            );
            return (
              <li key={item.id}>
                <Link
                  href={`/vote/${item.id}`}
                  className="flex flex-row justify-center"
                >
                  <div
                    // className="proposal-link-item"
                    // className="proposal-link-item bg-gradient-to-b from-gray-700 to-gray-900 border border-red-500 p-4 rounded-lg shadow-lg 
                    className="proposal-link-item bg-gradient-to-b from-gray-700 to-gray-900 border border-red-500 p-4 rounded-lg shadow-lg 
          cursor-pointer transform transition duration-500 hover:scale-[1.01] hover:shadow-xl"
                    style={{ width: "100%", maxWidth: "1200px" }}
                  >
                    <div>
                      <div
                        className="text-2xl font-semibold mb-2 text-purple-400 font-serif "
                        style={{ width: "100%", maxWidth: "700px" }}
                      >
                        {item.title}
                      </div>
                      <div
                        // className="mb-2 line-clamp-1"
                        className="mb-2 line-clamp-1 text-lg font-medium text-slate-100 mt-2 font-mono tracking-tighter"
                        style={{ width: "100%", maxWidth: "700px" }}
                      >
                        {item.description}
                      </div>
                      <div className="mb-2 text-base font-medium text-slate-100 mt-2 font-mono tracking-tighter">
                        {startDate} - {endDate}
                      </div>
                      <div className="mb-2">DAO Token: {item.tokenName}</div>
                      <div className="flex flex-row items-center">
                        <div
                          className={cn(
                            "mr-2 w-4 h-4 rounded-full bg",
                            // isActive ? "bg-green-600 " : "bg-stone-600",
                            isActive ? "bg-[#FF007F] " : "bg-[#008080]",
                          )}
                        />{" "}
                        {/* {isActive ? "Live" : "Completed"} */}
                        {isActive ? (
                          <p className="text-[#daacc3] font-mono font-medium">Live</p>
                        ) : (
                          <p className="text-[#5dbebe] font-mono font-medium">Completed</p>
                        )}
                      </div>
                    </div>
                    <div className="flex flex-col justify-between">
                      <div className="proposal-link-item__chain">
                        Proposal Created on
                        <img
                          src={`https://s2.coinmarketcap.com/static/img/coins/64x64/${originChainImg}.png`}
                          width={32}
                          height={32}
                          className="rounded-full ml-2"
                        />
                      </div>
                      <div className="flex sm:flex-row flex-col sm:items-center">
                        <div className="md:mb-0 mb-2">Voting available on</div>
                        <div className="flex flex-row">
                          {rearrangedSupportedChains.map((chain) => (
                            <img
                              src={`https://s2.coinmarketcap.com/static/img/coins/64x64/${chain.img}.png`}
                              width={32}
                              height={32}
                              className="rounded-full ml-2"
                              key={chain.definition.id}
                            />
                          ))}
                        </div>
                      </div>
                    </div>
                  </div>
                </Link>
              </li>
            );
          })}
        </ul>
        {!!proposalsLengthNumber && proposalsLengthNumber > PAGINATION_SIZE && (
          <div className="mb-16">
            <Pagination
              count={getPaginationCount(proposalsLengthNumber)}
              page={pageNumber}
              onChange={onChangePageNumber}
            />
          </div>
        )}
      </div>
    </div>
  );
}
