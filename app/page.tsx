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
    <div className="h-[90vh] flex justify-center">
      <div className="border-x border-x-slate-400 w-[80vw] pt-8 overflow-scroll ">

      <ul className="h-full px-8">
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
                  className="proposal-link-item"
                  style={{ width: "100%", maxWidth: "1200px" }}
                >
                  <div>
                    <div
                      className="text-xl font-semibold mb-2 line-clamp-1"
                      style={{ width: "100%", maxWidth: "700px" }}
                    >
                      {item.title}
                    </div>
                    <div
                      className="mb-2 line-clamp-1"
                      style={{ width: "100%", maxWidth: "700px" }}
                    >
                      {item.description}
                    </div>
                    <div className="mb-2">
                      {startDate} - {endDate}
                    </div>
                    <div className="mb-2">DAO Token: {item.tokenName}</div>
                    <div className="flex flex-row items-center">
                      <div
                        className={cn(
                          "mr-2 w-4 h-4 rounded-full bg",
                          isActive ? "bg-green-600" : "bg-stone-600",
                        )}
                      />{" "}
                      {isActive ? "Live" : "Completed"}
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
