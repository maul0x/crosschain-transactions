// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IERC20.sol";

/**
 * @title CT_CrossChainSender
 * @notice A contract that facilitates cross-chain ERC20 token deposits
 *         using Wormhole's TokenBridge and Relayer SDK.
 *
 * ### High-Level Workflow:
 * 1. A user calls {sendCrossChainDeposit} on the source chain.
 * 2. The contract:
 *    - Collects the required cross-chain fee (quoted from Wormhole relayer).
 *    - Pulls tokens from the sender via {IERC20.transferFrom}.
 *    - Encodes the recipient address into a payload.
 *    - Sends both tokens and payload cross-chain using Wormhole's relayer.
 * 3. The paired contract (e.g., {CrossChainReceiver}) on the destination chain
 *    receives the message and tokens, and finalizes delivery to the recipient.
 *
 * ### Security Notes:
 * - Users must approve this contract to spend tokens before calling
 *   {sendCrossChainDeposit}.
 * - The required Wormhole relayer fee must be sent with the transaction (`msg.value`).
 * - GAS_LIMIT is hardcoded to ensure enough execution gas for the destination call.
 *
 * ### Deployment Notes:
 * - This contract must be deployed on the source chain(s) from which tokens
 *   will be sent.
 * - The constructor requires Wormhole dependencies: relayer, token bridge, core.
 */
contract CT_CrossChainSender is TokenSender {
    /// @notice Gas limit allocated for the execution of the target chain transaction.
    /// @dev This constant ensures that destination execution will not run out of gas.
    uint256 constant GAS_LIMIT = 250_000;

    /**
     * @notice Initializes the CrossChainSender contract.
     * @param _wormholeRelayer Address of the Wormhole Relayer contract on the current chain.
     * @param _tokenBridge Address of the Wormhole TokenBridge contract on the current chain.
     * @param _wormhole Address of the Wormhole core contract on the current chain.
     *
     * @dev Calls {TokenBase} constructor to configure cross-chain messaging dependencies.
     */
    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    )
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    { }

    /**
     * @notice Returns the estimated fee required to perform a cross-chain deposit.
     * @param targetChain The Wormhole chain ID of the target (destination) chain.
     * @return cost The total fee (in wei) required to execute the delivery.
     *
     * @dev The fee consists of:
     *  - The Wormhole relayer’s delivery fee for sending a token+payload message.
     *  - The Wormhole message publication fee.
     *
     * Example:
     * ```solidity
     * uint256 cost = sender.quoteCrossChainDeposit(5);
     * ```
     */
    function quoteCrossChainDeposit(uint16 targetChain) public view returns (uint256 cost) {
        // Get the cost of delivering the token and payload to the target chain
        uint256 deliveryCost;
        (deliveryCost,) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0, // receiver value (set to 0 in this implementation)
            GAS_LIMIT
        );

        // Total cost: delivery fee + Wormhole message publication fee
        cost = deliveryCost + wormhole.messageFee();
    }

    /**
     * @notice Sends tokens and a payload (recipient address) to a target chain.
     * @param targetChain Wormhole chain ID for the target (destination) chain.
     * @param targetReceiver The address of the {TokenReceiver} contract on the target chain.
     * @param recipient The recipient’s address on the target chain (decoded in the receiver).
     * @param amount The amount of tokens to transfer.
     * @param token The ERC20 token contract address of the asset being transferred.
     *
     * @dev Workflow:
     *  - Quotes the cost of delivery with {quoteCrossChainDeposit}.
     *  - Requires the caller to provide the exact quoted fee in `msg.value`.
     *  - Pulls the token amount from the caller (must be approved beforehand).
     *  - Encodes the `recipient` address into the payload.
     *  - Uses {sendTokenWithPayloadToEvm} (from Wormhole SDK) to send the tokens + payload.
     *
     * @custom:require msg.value == quoteCrossChainDeposit(targetChain)
     *         Ensures the sender provides the correct fee for delivery.
     * @custom:require IERC20(token).transferFrom succeeds
     *         Caller must have approved the token transfer.
     *
     * Example:
     * ```solidity
     * // User wants to send 100 tokens to address R on chain X:
     * token.approve(address(sender), 100);
     * sender.sendCrossChainDeposit{value: sender.quoteCrossChainDeposit(X)}(
     *     X,
     *     receiverOnChainX,
     *     recipientAddress,
     *     100,
     *     address(token)
     * );
     * ```
     */
    function sendCrossChainDeposit(
        uint16 targetChain, // Wormhole chain ID for the target chain
        address targetReceiver, // Address of the TokenReceiver contract on the target chain
        address recipient, // Recipient address on the target chain
        uint256 amount, // Amount of tokens to send
        address token // ERC20 token contract address
    )
        public
        payable
    {
        // Get the delivery cost for this target chain
        uint256 cost = quoteCrossChainDeposit(targetChain);
        require(msg.value == cost, "msg.value must equal quoteCrossChainDeposit(targetChain)");

        // Transfer the specified amount of tokens from sender to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Encode the recipient's address into a payload (decoded on the receiver side)
        bytes memory payload = abi.encode(recipient);

        // Send the token + payload cross-chain using Wormhole SDK
        sendTokenWithPayloadToEvm(
            targetChain,
            targetReceiver,
            payload,
            0, // receiver value (set to 0 in this example)
            GAS_LIMIT,
            token,
            amount
        );
    }
}
