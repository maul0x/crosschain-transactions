// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IERC20.sol";

/**
 * @title CrossChainReceiver
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
contract CrossChainReceiver is TokenReceiver {
        // The wormhole relayer and registeredSenders are inherited from the Base.sol contract.
    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    )
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    { }

    // Function to receive the cross-chain payload and tokens with emitter validation
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