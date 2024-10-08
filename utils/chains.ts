import {
  sepolia,
  arbitrumSepolia,
  optimismSepolia,
  baseSepolia,
  blastSepolia,
} from "wagmi/chains";
import { Address, type Chain as Definition } from "viem";
import { Addresses } from "@/utils/addresses";

export type Chain = {
  chainSelector: number;
  name: string;
  img: number;
  definition: Definition;
  equitoVoteContract: Address;
  faucet: Address;
  voteSphere: Address;
  metaQuorum: Address;
  chainLight: Address;
};

export type SupportedChainsMap = Record<number, Chain>;

export const ethereumChain = {
  chainSelector: 1001,
  name: "Ethereum Sepolia",
  img: 1027,
  definition: sepolia,
  equitoVoteContract: Addresses.EthereumSepolia.EquitoVote,
  faucet: Addresses.EthereumSepolia.Faucet,
  voteSphere: Addresses.EthereumSepolia.VoteSphereToken,
  metaQuorum: Addresses.EthereumSepolia.MetaQuorumToken,
  chainLight: Addresses.EthereumSepolia.ChainLightToken,
};

export const arbitrumChain = {
  chainSelector: 1004,
  name: "Arbitrum Sepolia",
  img: 11841,
  definition: arbitrumSepolia,
  equitoVoteContract: Addresses.ArbitrumSepolia.EquitoVote,
  faucet: Addresses.ArbitrumSepolia.Faucet,
  voteSphere: Addresses.ArbitrumSepolia.VoteSphereToken,
  metaQuorum: Addresses.ArbitrumSepolia.MetaQuorumToken,
  chainLight: Addresses.ArbitrumSepolia.ChainLightToken,
};

export const optimismChain = {
  chainSelector: 1006,
  name: "Optimism Sepolia",
  img: 11840,
  definition: optimismSepolia,
  equitoVoteContract: Addresses.OptimismSepolia.EquitoVote,
  faucet: Addresses.OptimismSepolia.Faucet,
  voteSphere: Addresses.OptimismSepolia.VoteSphereToken,
  metaQuorum: Addresses.OptimismSepolia.MetaQuorumToken,
  chainLight: Addresses.OptimismSepolia.ChainLightToken,
};

export const baseChain = {
  chainSelector: 1007,
  name: "Base Sepolia",
  img: 9195,
  definition: baseSepolia,
  equitoVoteContract: Addresses.BaseSepolia.EquitoVote,
  faucet: Addresses.BaseSepolia.Faucet,
  voteSphere: Addresses.BaseSepolia.VoteSphereToken,
  metaQuorum: Addresses.BaseSepolia.MetaQuorumToken,
  chainLight: Addresses.BaseSepolia.ChainLightToken,
};

export const blastChain = {
  chainSelector: 1018,
  name: "Blast Sepolia",
  img: 28480,
  definition: blastSepolia,
  equitoVoteContract: Addresses.BlastSepolia.EquitoVote,
  faucet: Addresses.BlastSepolia.Faucet,
  voteSphere: Addresses.BlastSepolia.VoteSphereToken,
  metaQuorum: Addresses.BlastSepolia.MetaQuorumToken,
  chainLight: Addresses.BlastSepolia.ChainLightToken,
};

export const supportedChains: Chain[] = [
  ethereumChain,
  arbitrumChain,
  optimismChain,
  baseChain,
  blastChain,
];

export const supportedChainsMap = supportedChains.reduce(
  (acc: SupportedChainsMap, curr) => {
    acc[curr.definition.id] = curr;
    return acc;
  },
  {},
);

export const supportedChainsMapBySelector = supportedChains.reduce(
  (acc: SupportedChainsMap, curr) => {
    acc[curr.chainSelector] = curr;
    return acc;
  },
  {},
);

export const NATIVE_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

export const destinationChain = arbitrumChain;
