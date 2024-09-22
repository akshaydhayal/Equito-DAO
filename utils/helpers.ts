import { FormattedProposal, ProposalDataItem, ProposalResponse } from "@/types";
import { format } from "date-fns";
import { Chain, SupportedChainsMap } from "./chains";

export const PAGINATION_SIZE = 20;

// The order is important for this object.
export const placeholderProposal: FormattedProposal = {
  startTimestamp: 0,
  endTimestamp: 0,
  numVotesYes: 0,
  numVotesNo: 0,
  numVotesAbstain: 0,
  title: "",
  description: "",
  id: "",
  tokenName: "",
  startBlockNumber: 0,
  originChainSelector: 0,
};

export function isValidData<T>(data: T) {
  return !!data || data === 0 || data === BigInt(0);
}

export function isArrayNotEmpty<T>(data: T[]) {
  return Array.isArray(data) && !!data.length;
}

export function formatProposalItem(data: ProposalDataItem) {
  return typeof data === "bigint" ? Number(data) : data;
}

export function formatProposal(proposal: ProposalResponse) {
  return !proposal
    ? {}
    : Object.entries(proposal).reduce(
        (acc, [key, value]) => {
          acc[key] = formatProposalItem(value);
          return acc;
        },
        {} as Record<string, any>,
      );
}

export function formatProposals(proposals: ProposalResponse[]) {
  return !Array.isArray(proposals)
    ? []
    : proposals.map((proposal) => formatProposal(proposal));
}

export function buildProposalFromArray(
  proposalArrayData: Array<ProposalDataItem>,
) {
  return !Array.isArray(proposalArrayData)
    ? {}
    : Object.keys(placeholderProposal).reduce(
        (acc, key, index) => {
          acc[key] = formatProposalItem(proposalArrayData[index]);
          return acc;
        },
        {} as Record<string, any>,
      );
}

export function verifyIsGetPastVotesEnabled() {
  return process.env.NEXT_PUBLIC_IS_GET_PAST_VOTES_ENABLED_ENABLED === "true";
}

export function verifyIsProposalActive(proposal: FormattedProposal) {
  return proposal.endTimestamp > Math.floor(Date.now() / 1000);
}

export function formatTimestamp(
  timestampSeconds: number,
  isUSformatEnabled = true,
) {
  if (!timestampSeconds) {
    return "";
  }
  if (isUSformatEnabled) {
    return format(timestampSeconds * 1000, "dd MMM yyyy hh:mm a");
  }
  return format(timestampSeconds * 1000, "dd MMM yyyy HH:mm");
}

export function rearrangeChainMap(
  chainMap: SupportedChainsMap,
  target: number,
) {
  const chainMapCopy = { ...chainMap };
  delete chainMapCopy[target];
  return { ...chainMap[target], ...chainMapCopy };
}

export function rearrangeChains(
  chains: Chain[],
  chainSelectorTarget: number,
  shouldAppend = false,
) {
  const target = chains.find(
    (item) => chainSelectorTarget === item.chainSelector,
  );
  if (!target) {
    return chains;
  }
  const filteredChains = chains.filter(
    (item) => chainSelectorTarget !== item.chainSelector,
  );
  if (shouldAppend) {
    return [...filteredChains, target];
  }
  return [target, ...filteredChains];
}

export function buildTxLink(chain: Chain, hash: string) {
  const blockExplorerUrl = chain?.definition?.blockExplorers?.default?.url;
  return blockExplorerUrl ? `${blockExplorerUrl}/tx/${hash}` : "";
}
