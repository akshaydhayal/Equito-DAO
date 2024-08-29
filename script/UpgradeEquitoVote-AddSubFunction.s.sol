// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {DiamondCutFacet} from "../src/DiamondCutFacet.sol";
import {EquitoVote} from "../src/EquitoVote.sol";

contract AddSubFunctionToDiamond is Script {
    address constant DIAMOND_ADDRESS = 0x1234;

    function run() external {
        vm.startBroadcast();

        // Deploy the EquitoVote facet (if it hasn't been deployed yet) -- is this needed?
        // EquitoVote equitoVoteFacet = EquitoVote(0x1234);

        // Prepare the function selectors
        functionSelectors[0] = EquitoVote.sub.selector;

        // Prepare the facet cut (add action)
        IDiamondCut.FacetCut;
        facetCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(equitoVoteFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        // Get the DiamondCutFacet contract
        DiamondCutFacet diamondCutFacet = DiamondCutFacet(DIAMOND_ADDRESS);

        // Execute the diamondCut function to add the new function to the facet
        diamondCutFacet.diamondCut(facetCut, address(0), "");

        vm.stopBroadcast();

        console.log("EquitoVote facet (sub function) added to Diamond at:", DIAMOND_ADDRESS);
    }
}
