// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IERC20.sol";

/**
 * @title CT_CrossChainReceiver
 * @notice This contract enables the reception of cross-chain token transfers
 *         via the Wormhole messaging and token bridge system.
 * @dev This contract extends {TokenReceiver}, which itself relies on Wormhole's
 *      relayer infrastructure to validate and deliver cross-chain messages.
 *
 * ### High-Level Workflow:
 * 1. A transaction is initiated on a source chain to send tokens cross-chain
 *    using the Wormhole TokenBridge and Relayer.
 * 2. Wormhole verifies and relays the message + tokens to this target chain.
 * 3. The `receivePayloadAndTokens` function is triggered internally by the Wormhole relayer
 *    once the message and tokens arrive.
 * 4. The contract decodes the payload (which contains the recipient address),
 *    validates the sender, and transfers the received tokens to the intended recipient.
 *
 * ### Security Notes:
 * - Only messages from registered and verified source contracts are processed
 *   (via the {isRegisteredSender} modifier).
 * - The Wormhole relayer enforces authenticity (via the {onlyWormholeRelayer} modifier).
 * - Exactly one token transfer must accompany the payload (enforced by `require`).
 *
 * ### Deployment Notes:
 * - This contract should be deployed on each destination chain where
 *   cross-chain transfers need to be received.
 * - The constructor requires addresses of the Wormhole relayer, token bridge, and Wormhole core.
 */
contract CT_CrossChainReceiver is TokenReceiver {
    /**
     * @notice Initializes the CrossChainReceiver contract.
     * @param _wormholeRelayer The address of the Wormhole Relayer contract
     *        responsible for delivering cross-chain messages.
     * @param _tokenBridge The address of the Wormhole Token Bridge contract
     *        that locks/mints tokens across chains.
     * @param _wormhole The address of the Wormhole core contract
     *        that verifies VAAs (Verified Action Approvals).
     *
     * @dev Calls the {TokenBase} constructor (inherited from Wormhole SDK)
     *      to set up the relayer and bridge dependencies.
     */
    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    )
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    { }

    /**
     * @notice Internal function executed when a cross-chain message and tokens
     *         are received from Wormhole.
     *
     * @dev This function:
     *  - Can only be called by the Wormhole Relayer ({onlyWormholeRelayer}).
     *  - Validates that the sender is a registered source contract
     *    on the expected source chain ({isRegisteredSender}).
     *  - Requires exactly one token transfer to accompany the payload.
     *  - Decodes the payload to extract the recipient address.
     *  - Approves and then transfers the received tokens to the recipient.
     *
     * @param payload ABI-encoded data sent from the source chain.
     *        - Expected to contain the recipient's address (decoded as `address`).
     * @param receivedTokens Array of {TokenReceived} structs containing details
     *        of the transferred tokens (address, amount, origin).
     *        - Must contain exactly one entry.
     * @param sourceAddress The contract address (on the source chain)
     *        that initiated the cross-chain transfer.
     * @param sourceChain The Wormhole chain ID of the source chain.
     *
     * @custom:require receivedTokens.length == 1
     *           Ensures only one token transfer is processed.
     * @custom:security only callable via Wormhole relayer and from registered source.
     */
    function receivePayloadAndTokens(
        bytes memory payload,
        TokenReceived[] memory receivedTokens,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash (not used in this implementation)
    )
        internal
        override
        onlyWormholeRelayer
        isRegisteredSender(sourceChain, sourceAddress)
    {
        require(receivedTokens.length == 1, "Expected 1 token transfer");

        // Decode the recipient address from the payload
        address recipient = abi.decode(payload, (address));

        IERC20(receivedTokens[0].tokenAddress).approve(recipient, receivedTokens[0].amount);
        // Transfer the received tokens to the intended recipient
        IERC20(receivedTokens[0].tokenAddress).transfer(recipient, receivedTokens[0].amount);
    }
}
