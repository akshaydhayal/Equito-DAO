// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EquitoApp} from "equito/src/EquitoApp.sol";
import {bytes64, EquitoMessage} from "equito/src/libraries/EquitoMessageLibrary.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IVotesExtension} from "./IVotesExtension.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title EquitoVote
/// @notice Multichain DAO voting developed on the Equito Network.
contract EquitoVote is EquitoApp, ReentrancyGuard {
    // --- types ----

    /// @notice Options for voting.
    enum VoteOption {
        Yes,
        No,
        Abstain
    }

    /// @notice Cross-chain operation type.
    enum OperationType {
        CreateProposal,
        VoteOnProposal
    }

    /// @notice Main data structure to hold proposa data.
    struct Proposal {
        // When proposal was created.
        uint256 startTimestamp;
        // When proposal will end.
        uint256 endTimestamp;
        // Total number of Yes votes.
        uint256 numVotesYes;
        // Total number of No votes.
        uint256 numVotesNo;
        // Total number of Abstain votes.
        uint256 numVotesAbstain;
        // Proposal title.
        string title;
        // Proposal description.
        string description;
        // ID of a proposal.
        bytes32 id;
        // Name of the DAO token being used for this proposal.
        string tokenName;
        // Block number when the proposal was created.
        // ERC20Votes uses block.number by default for snapshots.
        uint256 startBlockNumber;
        // Chain where the proposal was created.
        uint256 originChainSelector;
    }

    // --- state variables ---

    /// @notice Protocol fee for creating proposals,
    ///         small value for us to simulate on Equito Builder Program.
    uint256 public createProposalFee = 0.000001e18;

    /// @notice Protocol fee for voting on proposals,
    ///         small value for us to simulate on Equito Builder Program.
    uint256 public voteOnProposalFee = 0.0000001e18;

    /// @notice List of proposal IDs.
    bytes32[] public proposalIds;

    /// @notice Proposal mapped by ID.
    mapping(bytes32 id => Proposal) public proposals;

    /// @notice Amount of user votes for each proposal.
    mapping(address user => mapping(bytes32 proposalId => uint256 votes))
        public userVotes;

    /// @notice Token data used as a security mechanism.
    mapping(string tokenName => mapping(uint256 chainSelector => address tokenAddress))
        public tokenData;

    /// @notice List of all token names.
    string[] public tokenNames;

    // --- events ---

    /// @notice Emitted when a proposal creation message is sent to another chain.
    /// @param proposalId ID of the proposal being created.
    /// @param destinationChainSelector The destination chain where the message is being sent.
    /// @param messageHash Hash of the message sent for proposal creation.
    event CreateProposalMessageSent(
        bytes32 indexed proposalId,
        uint256 indexed destinationChainSelector,
        bytes32 messageHash
    );

    /// @notice Emitted when a vote message on a proposal is sent to another chain.
    /// @param destinationChainSelector The destination chain where the vote message is being sent.
    /// @param messageHash Hash of the message sent for voting.
    event VoteOnProposalMessageSent(
        uint256 indexed destinationChainSelector,
        bytes32 messageHash
    );

    /// @notice Emitted when a proposal creation message is received from another chain.
    /// @param proposalId ID of the received proposal.
    event CreateProposalMessageReceived(bytes32 proposalId);

    /// @notice Emitted when a vote message on a proposal is received from another chain.
    /// @param proposalId ID of the proposal being voted on.
    /// @param numVotes Number of votes received.
    /// @param voteOption The voting option selected.
    event VoteOnProposalMessageReceived(
        bytes32 indexed proposalId,
        uint256 numVotes,
        VoteOption voteOption
    );

    /// @notice Emitted when the fee for creating a proposal is updated.
    /// @param newCreateProposaFee The updated fee for creating a proposal.
    event CreateProposalFeeUpdated(uint256 newCreateProposaFee);

    /// @notice Emitted when the fee for voting on a proposal is updated.
    /// @param newVoteOnProposalFee The updated fee for voting on a proposal.
    event VoteOnProposalFeeUpdated(uint256 newVoteOnProposalFee);

    /// @notice Emitted when token data is updated across multiple chains.
    /// @param tokenName Name of the token being updated.
    /// @param chainSelectors The chain selectors for the updated token data.
    /// @param tokenAddresses The addresses of the tokens on respective chains.
    event TokenDataUpdated(
        string indexed tokenName,
        uint256[] chainSelectors,
        address[] tokenAddresses
    );

    /// @notice Emitted when token data is deleted across multiple chains.
    /// @param tokenName Name of the token whose data is being deleted.
    /// @param chainSelectors The chain selectors for the deleted token data.
    event TokenDataDeleted(string tokenName, uint256[] chainSelectors);

    /// @notice Emitted when token data is updated for a specific chain.
    /// @param tokenName Name of the token being updated.
    /// @param chainSelector The chain selector for the updated token data.
    /// @param tokenAddress The address of the token on the specified chain.
    event TokenDataUpdated(
        string tokenName,
        uint256 chainSelector,
        address tokenAddress
    );

    // --- errors ---

    /// @notice Error emitted when attempting to interact with a proposal that is not yet finished.
    /// @param proposalId The ID of the proposal.
    /// @param endTimestamp The timestamp when the proposal will finish.
    error ProposalNotFinished(bytes32 proposalId, uint256 endTimestamp);

    /// @notice Error emitted when interacting with an invalid proposal.
    /// @param proposalId The ID of the invalid proposal.
    error InvalidProposal(bytes32 proposalId);

    /// @notice Error emitted when calling a contract or calling an EOA with
    ///         `.call` fails.
    /// @param destination The address where the call failed.
    error CallFailed(address destination);

    /// @notice Error emitted when an invalid token is provided for an operation.
    /// @param tokenName The name of the invalid token.
    /// @param sourceChainSelector The chain selector where the invalid token is located.
    /// @param tokenAddress The address of the invalid token.
    error InvalidToken(
        string tokenName,
        uint256 sourceChainSelector,
        address tokenAddress
    );

    /// @notice Error emitted when two arrays provided in an operation have mismatched lengths.
    /// @param firstArray Length of the first array.
    /// @param secondArray Length of the second array.
    error LengthMismatch(uint256 firstArray, uint256 secondArray);

    /// @notice Error emitted when trying to set token data that is already set.
    /// @param tokenName The name of the token that is already set.
    error TokenAlreadySet(string tokenName);

    /// @notice Error emitted when the user does not have enough delegated tokens to vote.
    /// @param numberUserVotes The number of votes the user has.
    /// @param numberUserDelegatedTokens The number of tokens delegated to the user.
    error NotEnoughDelegatedTokens(
        uint256 numberUserVotes,
        uint256 numberUserDelegatedTokens
    );

    // --- init function ---

    /// @notice Contract constructor.
    /// @param _router The address of the Equito router used for cross-chain messaging.
    constructor(address _router) EquitoApp(_router) {}

    // --- receive function ---

    /// @notice Plain native token transfers to this contract.
    receive() external payable {}

    // --- external mutative user functions ---

    /// @notice Create a cross chain proposal.
    /// @param destinationChainSelector The chain selector where the proposal is being sent.
    /// @param originChainSelector The chain selector where the proposal originates.
    /// @param endTimestamp The timestamp when the proposal will end.
    /// @param title The title of the proposal.
    /// @param description The description of the proposal.
    /// @param tokenName The name of the token used for voting.
    /// @dev Naming in the contracts and FE:
    ///      `sourceChain` = the chain the user is currently connected.
    ///      `originChain` = the chain a proposal was created, can be different from `sourceChain` at FE runtime.
    ///      `destinationChain` = the chain where `_receiveMessageFromPeers` gets called.
    function createProposal(
        uint256 destinationChainSelector,
        uint256 originChainSelector,
        uint256 endTimestamp,
        string calldata title,
        string calldata description,
        string calldata tokenName
    ) external payable nonReentrant {
        bytes32 id = keccak256(abi.encode(msg.sender, block.timestamp));

        Proposal memory newProposal = Proposal({
            startTimestamp: block.timestamp,
            startBlockNumber: block.number,
            endTimestamp: endTimestamp,
            numVotesYes: 0,
            numVotesNo: 0,
            numVotesAbstain: 0,
            title: title,
            description: description,
            id: id,
            tokenName: tokenName,
            originChainSelector: originChainSelector
        });

        bytes memory messageData = abi.encode(
            OperationType.CreateProposal,
            newProposal
        );

        bytes32 messageHash = router.sendMessage{
            value: msg.value - createProposalFee
        }(
            peers[destinationChainSelector],
            destinationChainSelector,
            messageData
        );

        emit CreateProposalMessageSent(
            id,
            destinationChainSelector,
            messageHash
        );
    }

    /// @notice Votes on an existing proposal.
    /// @param destinationChainSelector The chain selector where the vote is being sent.
    /// @param proposalId The ID of the proposal being voted on.
    /// @param numVotes The number of votes to cast.
    /// @param voteOption The vote option (Yes, No, Abstain).
    /// @param tokenAddress The address of the token used for voting.
    /// @param isGetPastVotesEnabled Flag to controler wheather we want past or current voting power.
    /// @dev `tokenAddress` will be validated in `_receiveMessageFromPeers._voteOnProposal` and
    ///      votes will only be counted if it's valid.
    function voteOnProposal(
        uint256 destinationChainSelector,
        bytes32 proposalId,
        uint256 numVotes,
        VoteOption voteOption,
        address tokenAddress,
        bool isGetPastVotesEnabled
    ) external payable nonReentrant {
        uint256 numberUserVotes = userVotes[msg.sender][proposalId];

        uint256 numberUserDelegatedTokens = getAmountDelegatedTokens(
            msg.sender,
            tokenAddress,
            proposalId, 
            isGetPastVotesEnabled
        );

        if (numVotes + numberUserVotes > numberUserDelegatedTokens) {
            revert NotEnoughDelegatedTokens(
                numberUserVotes,
                numberUserDelegatedTokens
            );
        }

        userVotes[msg.sender][proposalId] += numVotes;

        bytes64 memory receiver = peers[destinationChainSelector];

        uint256 normalizedNumVotes = numVotes /
            10 ** IERC20Metadata(tokenAddress).decimals();

        bytes memory messageData = abi.encode(
            OperationType.VoteOnProposal,
            proposalId,
            normalizedNumVotes,
            voteOption,
            tokenAddress
        );

        bytes32 messageHash = router.sendMessage{
            value: msg.value - voteOnProposalFee
        }(receiver, destinationChainSelector, messageData);

        emit VoteOnProposalMessageSent(destinationChainSelector, messageHash);
    }

    /// @notice Set token data to be used in proposals.
    /// @param tokenName The name of the token.
    /// @param chainSelectors An array of chain selectors for the token.
    /// @param tokenAddresses An array of addresses for the token.
    /// @dev Will be queried during voting to ensure the provided token matches
    ///		 the proposal token across different chains.
    function setTokenData(
        string calldata tokenName,
        uint256[] memory chainSelectors,
        address[] memory tokenAddresses
    ) external {
        uint256 tokenNamesLength = getTokenNamesLength();
        for (uint256 i = 0; i < tokenNamesLength; i = _uncheckedInc(i)) {
            if (
                keccak256(abi.encode(tokenName)) ==
                keccak256(abi.encode(tokenNames[i]))
            ) {
                revert TokenAlreadySet(tokenName);
            }
        }
        uint256 chainSelectorsLength = chainSelectors.length;
        uint256 tokenAddressesLength = tokenAddresses.length;
        if (chainSelectorsLength != tokenAddressesLength) {
            revert LengthMismatch(chainSelectorsLength, tokenAddressesLength);
        }
        for (uint256 i = 0; i < chainSelectorsLength; i = _uncheckedInc(i)) {
            tokenData[tokenName][chainSelectors[i]] = tokenAddresses[i];
        }
        tokenNames.push(tokenName);
        emit TokenDataUpdated(tokenName, chainSelectors, tokenAddresses);
    }

    // --- external mutative admin functions ---

    /// @notice Sets the creation fee for a proposal.
    /// @param newCreateProposalFee The new creation fee value, in wei.
    function setCreateProposalFee(
        uint256 newCreateProposalFee
    ) external onlyOwner {
        createProposalFee = newCreateProposalFee;
        emit CreateProposalFeeUpdated(newCreateProposalFee);
    }

    /// @notice Sets the fee for voting on a proposal.
    /// @param newVoteOnProposalFee The new vote-on-proposal fee value, in wei.
    function setVoteOnProposalFee(
        uint256 newVoteOnProposalFee
    ) external onlyOwner {
        newVoteOnProposalFee = newVoteOnProposalFee;
        emit VoteOnProposalFeeUpdated(newVoteOnProposalFee);
    }

    /// @notice Updates the token data for a given token.
    /// @param tokenName The name of the token to update.
    /// @param chainSelector The chain selector for the token data.
    /// @param tokenAddress The address associated with the token.
    function updateTokenData(
        string calldata tokenName,
        uint256 chainSelector,
        address tokenAddress
    ) external onlyOwner {
        tokenData[tokenName][chainSelector] = tokenAddress;
        emit TokenDataUpdated(tokenName, chainSelector, tokenAddress);
    }

    /// @notice Deletes the token data for a given token.
    /// @param tokenName The name of the token to delete.
    /// @param chainSelectors An array of chain selectors associated with the token data.
    function deleteTokenData(
        string calldata tokenName,
        uint256[] memory chainSelectors
    ) external onlyOwner {
        uint256 chainSelectorsLength = chainSelectors.length;
        for (uint256 i = 0; i < chainSelectorsLength; i = _uncheckedInc(i)) {
            tokenData[tokenName][chainSelectors[i]] = address(0);
        }
        uint256 tokenNamesLength = getTokenNamesLength();
        for (uint256 i = 0; i < tokenNamesLength; i = _uncheckedInc(i)) {
            if (
                keccak256(abi.encode(tokenName)) ==
                keccak256(abi.encode(tokenNames[i]))
            ) {
                tokenNames[i] = tokenNames[tokenNamesLength - 1];
                break;
            }
        }
        tokenNames.pop();
        emit TokenDataDeleted(tokenName, chainSelectors);
    }

    /// @notice Deletes a proposal by its ID.
    /// @param proposalId The ID of the proposal to delete.
    /// @dev If there are too many proposals, this function can run out of gas.
    ///      In that case, call `deleteProposalByIndexOptimized` which will
    ///      run more efficiently but it will not maintain the array order.
    function deleteProposalById(bytes32 proposalId) external onlyOwner {
        _deleteProposalFromMapping(proposalId);

        uint256 proposalIdIndex = 0;
        uint256 proposalIdsLength = getProposalIdsLength();
        bytes32[] memory proposalIdsCopy = proposalIds;
        for (uint256 i = 0; i < proposalIdsLength; i = _uncheckedInc(i)) {
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

    /// @notice Deletes a proposal at a specified index.
    /// @param proposalIndex The index of the proposal to delete.
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

    /// @notice Deletes a proposal at a specified index.
    /// @param proposalIndex The index of the proposal to delete.
    /// @dev Does not maintain the original array order.
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

    /// @notice Move the native token stored in this contract.
    /// @param destination The address to receive the native token.
    function transferFee(address destination) external onlyOwner {
        (bool success, ) = destination.call{value: address(this).balance}("");
        if (!success) {
            revert CallFailed(destination);
        }
    }

    // --- public view user functions ---

    /// @notice Get the length of all proposals.
    function getProposalIdsLength() public view returns (uint256) {
        return proposalIds.length;
    }

    /// @notice Get the length of all tokens.
    function getTokenNamesLength() public view returns (uint256) {
        return tokenNames.length;
    }

    // --- private view functions ---

    /// @notice Returns the amount of tokens delegated to a user at a specific proposal.
    /// @param user The address of the user.
    /// @param token The address of the token.
    /// @param proposalId The ID of the proposal.
    /// @param isGetPastVotesEnabled A flag indicating whether to get past votes or current votes.
    /// @return uint256 The amount of tokens delegated.
    /// @dev We use `isGetPastVotesEnabled` to control wheather we want to retrive a past voting power
    //       or the current one. For hackathon demonstrations on testnets, we want to enable the current
    //       voting power so that users/judges are able to vote of proposals even if they delegate tokens
    //       after the proposal is created.
    function getAmountDelegatedTokens(
        address user,
        address token,
        bytes32 proposalId,
        bool isGetPastVotesEnabled
    ) public view returns (uint256) {
        return
            isGetPastVotesEnabled
                ? IVotes(token).getPastVotes(
                    user,
                    keccak256(abi.encode(IVotesExtension(token).CLOCK_MODE)) ==
                        keccak256(abi.encode("mode=blocknumber&from=default"))
                        ? proposals[proposalId].startBlockNumber
                        : proposals[proposalId].endTimestamp
                )
                : IVotes(token).getVotes(user);
    }

    /// @notice Build up an array of proposals and return it using the index params.
    /// @param startIndex The start index, inclusive.
    /// @param endIndex The end index, non inclusive.
    /// @return An array with proposal data.
    function getSlicedProposals(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (Proposal[] memory) {
        Proposal[] memory slicedProposals = new Proposal[](
            endIndex - startIndex
        );
        bytes32[] memory proposalIdsCopy = proposalIds;
        for (uint256 i = startIndex; i < endIndex; i = _uncheckedInc(i)) {
            slicedProposals[i] = proposals[proposalIdsCopy[i]];
        }
        return slicedProposals;
    }

    /// @notice Build up an array of proposals in reverse order.
    /// @param startIndex The start index, inclusive.
    /// @param endIndex The end index, non inclusive.
    /// @return An array with proposal data.
    /// @dev Used to display the newest proposals first with pagination.
    function getSlicedReversedProposals(
        int256 startIndex,
        int256 endIndex
    ) external view returns (Proposal[] memory) {
        Proposal[] memory slicedProposals = new Proposal[](
            uint256(startIndex - endIndex)
        );
        bytes32[] memory proposalIdsCopy = proposalIds;
        uint256 i;
        for (int256 j = startIndex; j > endIndex; j = _uncheckedDec(j)) {
            slicedProposals[i] = proposals[proposalIdsCopy[uint256(j)]];
            unchecked {
                ++i;
            }
        }
        return slicedProposals;
    }

    /// @notice The the tokens name via pagination.
    /// @param startIndex Starting index, inclusive.
    /// @param endIndex End index, non-inclusive.
    function getSlicedTokenNames(
        uint256 startIndex,
        uint256 endIndex
    ) external view returns (string[] memory) {
        string[] memory slicedTokenNames = new string[](endIndex - startIndex);
        string[] memory tokenNamesCopy = tokenNames;
        uint256 i;
        for (uint256 j = startIndex; j < endIndex; j = _uncheckedInc(j)) {
            slicedTokenNames[i] = tokenNamesCopy[j];
            unchecked {
                ++i;
            }
        }
        return slicedTokenNames;
    }

    // --- internal mutative functions ---

    /// @notice Receive the cross chain message on the destination chain.
    /// @param message Equito message.
    /// @param messageData The data being received, where the proposal data is included.
    function _receiveMessageFromPeer(
        EquitoMessage calldata message,
        bytes calldata messageData
    ) internal override {
        OperationType operationType = abi.decode(messageData, (OperationType));
        if (operationType == OperationType.CreateProposal) {
            (, Proposal memory newProposal) = abi.decode(
                messageData,
                (OperationType, Proposal)
            );
            _createProposal(newProposal);
            emit CreateProposalMessageReceived(newProposal.id);
        } else if (operationType == OperationType.VoteOnProposal) {
            (
                ,
                bytes32 proposalId,
                uint256 numVotes,
                VoteOption voteOption,
                address tokenAddress
            ) = abi.decode(
                    messageData,
                    (OperationType, bytes32, uint256, VoteOption, address)
                );
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

    /// @notice Stores a new proposal.
    /// @param newProposal New proposal being created.
    function _createProposal(Proposal memory newProposal) private {
        bytes32 proposalId = newProposal.id;
        proposalIds.push(proposalId);
        proposals[proposalId] = newProposal;
    }

    /// @notice Updates the vote count for a proposal.
    /// @param proposalId The ID of the proposal to update.
    /// @param numVotes The number of votes to add.
    /// @param voteOption The option of the vote (Yes, No, or Abstain).
    /// @param tokenAddress The address of the token associated with the proposal.
    /// @param sourceChainSelector The selector for the source chain.
    function _voteOnProposal(
        bytes32 proposalId,
        uint256 numVotes,
        VoteOption voteOption,
        address tokenAddress,
        uint256 sourceChainSelector
    ) private {
        string memory tokenName = proposals[proposalId].tokenName;
        if (
            tokenAddress == address(0) ||
            tokenData[tokenName][sourceChainSelector] != tokenAddress
        ) {
            revert InvalidToken(tokenName, sourceChainSelector, tokenAddress);
        }
        if (voteOption == VoteOption.Yes) {
            proposals[proposalId].numVotesYes += numVotes;
        } else if (voteOption == VoteOption.No) {
            proposals[proposalId].numVotesNo += numVotes;
        } else if (voteOption == VoteOption.Abstain) {
            proposals[proposalId].numVotesAbstain += numVotes;
        }
    }

    /// @notice Deletes proposal from the active mapping.
    /// @param proposalIdToDelete ID target to delete a proposal from.
    function _deleteProposalFromMapping(bytes32 proposalIdToDelete) private {
        Proposal memory emptyProposal;
        proposals[proposalIdToDelete] = emptyProposal;
    }

    /// @notice Delete a proposal by index.
    /// @param proposalIndex The Index to delete.
    /// @param proposalIdsLength The length of the proposals list.
    /// @param proposalIdsCopy  The copy of the proposal ids.
    function _deleteProposalFromListByIndex(
        uint256 proposalIndex,
        uint256 proposalIdsLength,
        bytes32[] memory proposalIdsCopy
    ) private {
        if (proposalIndex != proposalIdsLength - 1) {
            for (
                uint256 i = proposalIndex;
                i < proposalIdsLength - 1;
                i = _uncheckedInc(i)
            ) {
                proposalIds[i] = proposalIdsCopy[i + 1];
            }
        }
        proposalIds.pop();
    }

    // --- private pure functions ---

    /// @notice Unchecked increment to save gas. Should be used primarily on
    ///         `for` loops, since the value of `i` will be smaller than the
    ///         a target length, which is bound to be smaller than 2**256 - 1.
    /// @param i The value to be incremented.
    /// @return The incremeneted value.
    function _uncheckedInc(uint256 i) private pure returns (uint256) {
        unchecked {
            return ++i;
        }
    }

    /// @notice Unchecked decrement to save gas in for loops.
    /// @param i The value to be decremented.
    /// @return The decremented value.
    function _uncheckedDec(int256 i) private pure returns (int256) {
        unchecked {
            return --i;
        }
    }
}
