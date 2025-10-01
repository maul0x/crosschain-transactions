// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IERC20.sol";

contract CT_CrossChainSender is TokenSender {
    uint256 constant GAS_LIMIT = 250_000;

        constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    )
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    { }

    // Function to get the estimated cost for cross-chain deposit
    function quoteCrossChainDeposit(uint16 targetChain) public view returns (uint256 cost) {
        // Get the cost of delivering the token and payload to the target chain
        uint256 deliveryCost;
        (deliveryCost,) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0, // receiver value (set to 0 in this example)
            GAS_LIMIT
        );

        // Total cost: delivery cost + cost of publishing the Wormhole message
        cost = deliveryCost + wormhole.messageFee();
    }
}