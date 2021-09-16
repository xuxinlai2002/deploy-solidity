// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../interfaces/IDepositExecute.sol";
import "./HandlerHelpers.sol";

/**
    @title Handles ERC20 deposits and deposit executions.
    @author ChainSafe Systems.
    @notice This contract is intended to be used with the Bridge contract.
 */
contract WETHHandler is IDepositExecute, HandlerHelpers{

    // xxl TODO 2
    // struct DepositRecord {
    //     address _tokenAddress;
    //     uint8 _lenDestinationRecipientAddress;
    //     uint8 _destinationChainID;
    //     bytes32 _resourceID;
    //     bytes _destinationRecipientAddress;
    //     address _depositer;
    //     uint256 _amount;
    // }

    // xxl TODO 2
    // // depositNonce => Deposit Record
    // mapping(uint8 => mapping(uint64 => DepositRecord)) public _depositRecords;

    mapping(uint8 => mapping(uint64 => bytes32)) public _depositRecords;

    event DepositRecord(
        address _tokenAddress,
        uint8 _lenDestinationRecipientAddress,
        uint8 _destinationChainID,
        bytes32 _resourceID,
        bytes _destinationRecipientAddress,
        address _depositer,
        uint256 _amount
    );

    /**
        @param bridgeAddress Contract address of previously deployed Bridge.
        @param initialResourceIDs Resource IDs are used to identify a specific contract address.
        These are the Resource IDs this contract will initially support.
        @param initialContractAddresses These are the addresses the {initialResourceIDs} will point to, and are the contracts that will be
        called to perform various deposit calls.
        @param burnableContractAddresses These addresses will be set as burnable and when {deposit} is called, the deposited token will be burned.
        When {executeProposal} is called, new tokens will be minted.

        @dev {initialResourceIDs} and {initialContractAddresses} must have the same length (one resourceID for every address).
        Also, these arrays must be ordered in the way that {initialResourceIDs}[0] is the intended resourceID for {initialContractAddresses}[0].
     */
    constructor(
        address bridgeAddress,
        bytes32[] memory initialResourceIDs,
        address[] memory initialContractAddresses,
        address[] memory burnableContractAddresses
    ) public{
        require(
            initialResourceIDs.length == initialContractAddresses.length,
            "initialResourceIDs and initialContractAddresses len mismatch"
        );

        _bridgeAddress = bridgeAddress;

        for (uint256 i = 0; i < initialResourceIDs.length; i++) {
            _setResource(initialResourceIDs[i], initialContractAddresses[i]);
        }

        for (uint256 i = 0; i < burnableContractAddresses.length; i++) {
            _setBurnable(burnableContractAddresses[i]);
        }
    }

    /**
        @param depositNonce This ID will have been generated by the Bridge contract.
        @param destId ID of chain deposit will be bridged to.
        @return DepositRecord which consists of:
        - _tokenAddress Address used when {deposit} was executed.
        - _destinationChainID ChainID deposited tokens are intended to end up on.
        - _resourceID ResourceID used when {deposit} was executed.
        - _lenDestinationRecipientAddress Used to parse recipient's address from {_destinationRecipientAddress}
        - _destinationRecipientAddress Address tokens are intended to be deposited to on desitnation chain.
        - _depositer Address that initially called {deposit} in the Bridge contract.
        - _amount Amount of tokens that were deposited.
    */
    function getDepositRecord(uint64 depositNonce, uint8 destId)
        external view
        returns (bytes32)
    {
        return _depositRecords[destId][depositNonce];
    }

    /**
        @notice A deposit is initiatied by making a deposit in the Bridge contract.
        @param destinationChainID Chain ID of chain tokens are expected to be bridged to.
        @param depositNonce This value is generated as an ID by the Bridge contract.
        @param depositer Address of account making the deposit in the Bridge contract.
        @param data Consists of: {resourceID}, {amount}, {lenRecipientAddress}, and {recipientAddress}
        all padded to 32 bytes.
        @notice Data passed into the function should be constructed as follows:
        amount                      uint256     bytes   0 - 32
        recipientAddress length     uint256     bytes  32 - 64
        recipientAddress            bytes       bytes  64 - END
        @dev Depending if the corresponding {tokenAddress} for the parsed {resourceID} is
        marked true in {_burnList}, deposited tokens will be burned, if not, they will be locked.
     */
    function deposit(
        bytes32 resourceID,
        uint8 destinationChainID,
        uint64 depositNonce,
        address depositer,
        bytes calldata data
    ) external override onlyBridge {
        bytes memory recipientAddress;
        uint256 amount;
        uint256 lenRecipientAddress;

        (amount, lenRecipientAddress) = abi.decode(data, (uint, uint));
        recipientAddress = bytes(data[64:64 + lenRecipientAddress]);

        address tokenAddress = _resourceIDToTokenContractAddress[resourceID];
        require(
            _contractWhitelist[tokenAddress],
            "provided tokenAddress is not whitelisted"
        );


        _depositRecords[destinationChainID][depositNonce] = keccak256(
            abi.encode(
                tokenAddress,
                uint8(lenRecipientAddress),
                destinationChainID,
                resourceID,
                recipientAddress,
                depositer,
                amount
            )
        );

        //xxl TODO 2 emit _depositRecords
        emit DepositRecord(
            tokenAddress,
            uint8(lenRecipientAddress),
            destinationChainID,
            resourceID,
            recipientAddress,
            depositer,
            amount
        );


    }



    /**
        @notice Proposal execution should be initiated when a proposal is finalized in the Bridge contract.
        by a relayer on the deposit's destination chain.
        @param data Consists of {resourceID}, {amount}, {lenDestinationRecipientAddress},
        and {destinationRecipientAddress} all padded to 32 bytes.
        @notice Data passed into the function should be constructed as follows:
        amount                                 uint256     bytes  0 - 32
        destinationRecipientAddress length     uint256     bytes  32 - 64
        destinationRecipientAddress            bytes       bytes  64 - END
     */
    function executeProposal(bytes32 resourceID, bytes calldata data)
        external
        override
        onlyBridge
    {
        //emit LogString("come to wethhander executeProposal");
    }

    /**
        @notice get the handler type
     */
    function getType() external override pure returns(HandleTypes) {
        //return WETH;
        return IDepositExecute.HandleTypes.WETH;
    }

}
