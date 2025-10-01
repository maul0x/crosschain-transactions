// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "lib/wormhole-solidity-sdk/src/WormholeRelayerSDK.sol";
import "lib/wormhole-solidity-sdk/src/interfaces/IERC20.sol";

/**
 * @title CrossChainReceiver.
 * @notice A contract to handle receiving of tokens cross chain using wormhole cross chain token transfer.
 * @notice This contract is deployed on multiple chains to support multiple target chains.
 */
contract CrossChainReceiver {
        // The wormhole relayer and registeredSenders are inherited from the Base.sol contract.
    constructor(
        address _wormholeRelayer,
        address _tokenBridge,
        address _wormhole
    )
        TokenBase(_wormholeRelayer, _tokenBridge, _wormhole)
    { }
    
}