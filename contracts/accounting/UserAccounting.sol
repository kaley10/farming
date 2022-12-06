// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library UserAccounting {
    struct Info {
        uint40 checkpoint;
        uint216 farmedPerTokenStored;
        mapping(address => int256) corrections;
    }

    uint256 constant internal _SCALE = 1e6;

    function farmedPerToken(
        Info storage info,
        bytes32 context,
        function(bytes32) internal view returns(uint256) lazyGetSupply,
        function(bytes32, uint256) internal view returns(uint256) lazyGetFarmed
    ) internal view returns(uint256) {
        (uint256 checkpoint, uint256 fpt) = (info.checkpoint, info.farmedPerTokenStored);
        if (block.timestamp != checkpoint) {
            uint256 supply = lazyGetSupply(context);
            if (supply > 0) {
                uint256 changePerToken;
                unchecked { changePerToken = lazyGetFarmed(context, checkpoint) / supply; }
                fpt += changePerToken;
            }
        }
        return fpt;
    }

    function farmed(Info storage info, address account, uint256 balance, uint256 fpt) internal view returns(uint256) {
        return uint256(int256(balance * fpt) - info.corrections[account]) / _SCALE;
    }

    function eraseFarmed(Info storage info, address account, uint256 balance, uint256 fpt) internal {
        info.corrections[account] = int256(balance * fpt);
    }

    function updateFarmedPerToken(Info storage info, uint256 fpt) internal {
        (info.checkpoint, info.farmedPerTokenStored) = (uint40(block.timestamp), uint216(fpt));
    }

    function updateBalances(Info storage info, address from, address to, uint256 amount, uint256 fpt) internal {
        bool fromZero = (from == address(0));
        bool toZero = (to == address(0));
        if (amount > 0 && from != to) {
            if (fromZero || toZero) {
                updateFarmedPerToken(info, fpt);
            }

            int256 diff = int256(amount * fpt);
            if (!fromZero) {
                info.corrections[from] -= diff;
            }
            if (!toZero) {
                info.corrections[to] += diff;
            }
        }
    }
}
