// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EquitoApp} from "equito/src/EquitoApp.sol";
import {bytes64, EquitoMessage} from "equito/src/libraries/EquitoMessageLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract EquitoVote is EquitoApp, ReentrancyGuard {
    // --- types ----

    enum VoteOption {
        Yes,
        No,
        Abstain
    }

    enum OperationType {
        CreateProposal,
        VoteOnProposal
    }

    struct Proposal {
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 numVotesYes;
        uint256 numVotesNo;
        uint256 numVotesAbstain;
        string title;
        string description;
        bytes32 id;
        bytes32 tokenNameHash;
        // Chain where the proposal was created
        uint256 originChainSelector;
    }

    // --- state variables ---

    uint256 public protocolFee = 0.000001e18;

    bytes32[] public proposalIds;

    mapping(bytes32 id => Proposal) public proposals;

    mapping(address user => mapping(bytes32 proposalId => uint256 amount))
        public balances;

    mapping(bytes32 tokenNameHash => mapping(uint256 chainSelector => address tokenAddress))
        public tokenData;

    // --- extensions ---

    using SafeERC20 for IERC20;

    // --- events ---

    event CreateProposalMessageSent(
        uint256 indexed destinationChainSelector,
        bytes32 messageHash,
        bytes32 proposalId
    );

    event VoteOnProposalMessageSent(
        uint256 indexed destinationChainSelector,
        bytes32 messageHash
    );

    event CreateProposalMessageReceived(bytes32 proposalId);

    event VoteOnProposalMessageReceived(
        bytes32 indexed proposalId,
        uint256 numVotes,
        VoteOption voteOption
    );

    event ProtocolFeeUpdated(uint256 newProtocolFee);

    event TokenDataUpdated(
        bytes32 indexed tokenNameHash,
        uint256[] chainSelectors,
        address[] tokenAddresses
    );

    event TokenDataDeleted(bytes32 tokenNameHash, uint256[] chainSelectors);

    // --- errors ---

    error ProposalNotFinished(bytes32 proposalId, uint256 endTimestamp);

    error ProposalInvalid(bytes32 proposalId);

    error CallFailed(address destination);

    error InvalidToken(
        bytes32 tokenNameHash,
        uint256 sourceChainSelector,
        address tokenAddress
    );

    error LengthMismatch(
        uint256 chainSelectorsLength,
        uint256 tokenAddressesLength
    );

    // --- init function ---

    constructor(address _router) EquitoApp(_router) {}

    // --- receive function ---

    /// @notice Plain native token transfers to this contract.
    receive() external payable {}

    // --- external mutative user functions ---

    function createProposal(
        uint256 destinationChainSelector,
        uint256 endTimestamp,
        string calldata title,
        string calldata description,
        bytes32 tokenNameHash,
        uint256 originChainSelector
    ) external payable nonReentrant {
        bytes32 id = keccak256(abi.encode(msg.sender, block.timestamp));

        Proposal memory newProposal = Proposal({
            startTimestamp: block.timestamp,
            endTimestamp: endTimestamp,
            numVotesYes: 0,
            numVotesNo: 0,
            numVotesAbstain: 0,
            title: title,
            description: description,
            id: id,
            tokenNameHash: tokenNameHash,
            originChainSelector: originChainSelector
        });

        bytes memory messageData = abi.encode(
            OperationType.CreateProposal,
            bytes32(0),
            0,
            VoteOption.Abstain,
            address(0),
            newProposal
        );

        bytes32 messageHash = router.sendMessage{
            value: msg.value - protocolFee
        }(
            peers[destinationChainSelector],
            destinationChainSelector,
            messageData
        );

        emit CreateProposalMessageSent(
            destinationChainSelector,
            messageHash,
            id
        );
    }

    function voteOnProposal(
        uint256 destinationChainSelector,
        bytes32 proposalId,
        uint256 numVotes,
        VoteOption voteOption,
        address tokenAddress
    ) external payable nonReentrant {
        balances[msg.sender][proposalId] += numVotes;

        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            numVotes
        );

        bytes64 memory receiver = peers[destinationChainSelector];

        uint256 normalizedNumVotes = numVotes /
            IERC20Metadata(tokenAddress).decimals();

        Proposal memory emptyNewProposal;

        bytes memory messageData = abi.encode(
            OperationType.VoteOnProposal,
            proposalId,
            normalizedNumVotes,
            voteOption,
            tokenAddress,
            emptyNewProposal
        );

        bytes32 messageHash = router.sendMessage{value: msg.value}(
            receiver,
            destinationChainSelector,
            messageData
        );

        emit VoteOnProposalMessageSent(destinationChainSelector, messageHash);
    }

    // /// @dev Can only unlock all at once
    // function unlockTokens(bytes32 proposalId) external nonReentrant {
    //     Proposal memory proposal = proposals[proposalId];
    //     if (proposal.id == bytes32(0)) {
    //         revert ProposalInvalid(proposalId);
    //     }
    //     if (block.timestamp <= proposal.endTimestamp) {
    //         revert ProposalNotFinished(proposalId, proposal.endTimestamp);
    //     }
    //     uint256 amount = balances[msg.sender][proposalId];
    //     balances[msg.sender][proposalId] = 0;
    //     IERC20(proposal.erc20).safeTransfer(msg.sender, amount);
    // }

    function setTokenData(
        // string calldata name,
        bytes32 tokenNameHash,
        uint256[] memory chainSelectors,
        address[] memory tokenAddresses
    ) external {
        uint256 chainSelectorsLength = chainSelectors.length;
        uint256 tokenAddressesLength = tokenAddresses.length;
        if (chainSelectorsLength != tokenAddressesLength) {
            revert LengthMismatch(chainSelectorsLength, tokenAddressesLength);
        }
        for (uint256 i = 0; i < chainSelectorsLength; i = uncheckedInc(i)) {
            tokenData[tokenNameHash][chainSelectors[i]] = tokenAddresses[i];
        }
        emit TokenDataUpdated(tokenNameHash, chainSelectors, tokenAddresses);
    }

    // --- external mutative admin functions ---

    function setProtocolFee(uint256 newProtocolFee) external onlyOwner {
        protocolFee = newProtocolFee;
        emit ProtocolFeeUpdated(newProtocolFee);
    }

    function deleteTokenData(
        bytes32 tokenNameHash,
        uint256[] memory chainSelectors
    ) external onlyOwner {
        uint256 chainSelectorsLength = chainSelectors.length;
        for (uint256 i = 0; i < chainSelectorsLength; i = uncheckedInc(i)) {
            tokenData[tokenNameHash][chainSelectors[i]] = address(0);
        }
        emit TokenDataDeleted(tokenNameHash, chainSelectors);
    }

    /// @dev If there are too many proposals, this function can run out of gas.
    ///      In that case, call `deleteProposalByIndexOptimized` which will
    ///      run more efficiently but it will not maintain the array order.
    function deleteProposalById(bytes32 proposalId) external onlyOwner {
        _deleteProposalFromMapping(proposalId);

        uint256 proposalIdIndex = 0;
        uint256 proposalIdsLength = getProposalIdsLength();
        bytes32[] memory proposalIdsCopy = proposalIds;
        for (uint256 i = 0; i < proposalIdsLength; i = uncheckedInc(i)) {
            if (proposalId == proposalIdsCopy[i]) {
                proposalIdIndex = i;
                break;
            }
        }
        _deleteProposalFromListByIndex(
            proposalIdIndex,
            proposalIdsLength,
            proposalIdsCopy
        );
    }

    /// @dev If there are too many proposals, this function can run out of gas.
    ///      In that case, call `deleteProposalByIndexOptimized` which will
    ///      run more efficiently but it will not maintain the array order.
    function deleteProposalByIndex(uint256 proposalIndex) external onlyOwner {
        bytes32[] memory proposalIdsCopy = proposalIds;
        bytes32 proposalIdToDelete = proposalIdsCopy[proposalIndex];
        _deleteProposalFromMapping(proposalIdToDelete);
        _deleteProposalFromListByIndex(
            proposalIndex,
            getProposalIdsLength(),
            proposalIdsCopy
        );
    }

    function deleteProposalByIndexOptimized(
        uint256 proposalIndex
    ) external onlyOwner {
        bytes32[] memory proposalIdsCopy = proposalIds;
        bytes32 proposalIdToDelete = proposalIdsCopy[proposalIndex];
        _deleteProposalFromMapping(proposalIdToDelete);
        uint256 proposalIdsLength = proposalIdsCopy.length;
        if (proposalIndex != proposalIdsLength - 1) {
            proposalIds[proposalIndex] = proposalIdsCopy[proposalIdsLength - 1];
        }
        proposalIds.pop();
    }

    function transferFee(address destination) external onlyOwner {
        (bool success, ) = destination.call{value: address(this).balance}("");
        if (!success) {
            revert CallFailed(destination);
        }
    }

    // --- public view user functions ---

    function getProposalIdsLength() public view returns (uint256) {
        return proposalIds.length;
    }

    /// @notice Build up an array of proposals and return it using the index params.
    /// @param startIndex The start index, inclusive.
    /// @param endIndex The end index, non inclusive.
    /// @return An array with proposal data.
    function getProposalsSlice(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (Proposal[] memory) {
        Proposal[] memory slicedProposals = new Proposal[](
            endIndex - startIndex
        );
        bytes32[] memory proposalIdsCopy = proposalIds;
        for (uint256 i = startIndex; i < endIndex; i = uncheckedInc(i)) {
            slicedProposals[i] = proposals[proposalIdsCopy[i]];
        }
        return slicedProposals;
    }

    // --- internal mutative functions ---

    /// @notice Receve the cross chain message on the destination chain.
    function _receiveMessageFromPeer(
        EquitoMessage calldata message,
        bytes calldata messageData
    ) internal override {
        (
            OperationType operationType,
            bytes32 proposalId,
            uint256 numVotes,
            VoteOption voteOption,
            address tokenAddress,
            Proposal memory newProposal
        ) = abi.decode(
                messageData,
                (OperationType, bytes32, uint256, VoteOption, address, Proposal)
            );
        if (operationType == OperationType.CreateProposal) {
            _createProposal(newProposal);
            emit CreateProposalMessageReceived(newProposal.id);
        } else if (operationType == OperationType.VoteOnProposal) {
            _voteOnProposal(
                proposalId,
                numVotes,
                voteOption,
                tokenAddress,
                message.sourceChainSelector
            );
            emit VoteOnProposalMessageReceived(
                proposalId,
                numVotes,
                voteOption
            );
        }
    }

    // --- private mutative functions ---

    function _createProposal(Proposal memory newProposal) private {
        bytes32 proposalId = newProposal.id;
        proposalIds.push(proposalId);
        proposals[proposalId] = newProposal;
    }

    function _voteOnProposal(
        bytes32 proposalId,
        uint256 numVotes,
        VoteOption voteOption,
        address tokenAddress,
        uint256 sourceChainSelector
    ) private {
        bytes32 tokenNameHash = proposals[proposalId].tokenNameHash;
        if (
            tokenAddress == address(0) ||
            tokenData[tokenNameHash][sourceChainSelector] != tokenAddress
        ) {
            revert InvalidToken(
                tokenNameHash,
                sourceChainSelector,
                tokenAddress
            );
        }
        if (voteOption == VoteOption.Yes) {
            proposals[proposalId].numVotesYes += numVotes;
        } else if (voteOption == VoteOption.No) {
            proposals[proposalId].numVotesNo += numVotes;
        } else if (voteOption == VoteOption.Abstain) {
            proposals[proposalId].numVotesAbstain += numVotes;
        }
    }

    function _deleteProposalFromMapping(bytes32 proposalIdToDelete) private {
        Proposal memory emptyProposal;
        proposals[proposalIdToDelete] = emptyProposal;
    }

    function _deleteProposalFromListByIndex(
        uint256 proposalIndex,
        uint256 proposalIdsLength,
        bytes32[] memory proposalIdsCopy
    ) private {
        if (proposalIndex != proposalIdsLength - 1) {
            for (
                uint256 i = proposalIndex;
                i < proposalIdsLength - 1;
                i = uncheckedInc(i)
            ) {
                proposalIds[i] = proposalIdsCopy[i + 1];
            }
        }
        proposalIds.pop();
    }

    // --- private pure functions ---

    /// @notice Unchecked increment to save gas. Should be used primarily on
    ///			`for` loops, since the value of `i` will be smaller than the
    ///         a target length, which is bound to be smaller than 2**256 - 1.
    /// @param i The value to be incremented.
    /// @return The incremeneted value.
    function uncheckedInc(uint256 i) private pure returns (uint256) {
        unchecked {
            return ++i;
        }
    }
}
