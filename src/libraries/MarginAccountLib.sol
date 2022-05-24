// SPDX-License-Identifier: Unlicense
pragma solidity =0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "src/libraries/OptionTokenUtils.sol";

import "src/config/types.sol";
import "src/config/constants.sol";
import "src/config/errors.sol";

/**
 * @title MarginAccountLib
 * @dev   This library is in charge of updating the account memory and do validations
 */
library MarginAccountLib {
    function addCollateral(
        Account memory account,
        uint80 amount,
        uint32 productId
    ) internal pure {
        if (account.productId == 0) {
            account.productId = productId;
        } else {
            if (account.productId != productId) revert WrongProductId();
        }
        account.collateralAmount += amount;
    }

    function removeCollateral(Account memory account, uint80 amount) internal pure {
        account.collateralAmount -= amount;
        if (account.collateralAmount == 0) {
            account.productId = 0;
        }
    }

    function mintOption(
        Account memory account,
        uint256 tokenId,
        uint64 amount
    ) internal pure {
        (TokenType optionType, , , uint64 tokenLongStrike, uint64 tokenShortStrike) = OptionTokenUtils.parseTokenId(
            tokenId
        );

        // check that vanilla options doesnt have a shortStrike argument
        if ((optionType == TokenType.CALL || optionType == TokenType.PUT) && (tokenShortStrike != 0))
            revert InvalidTokenId();
        // check that you cannot mint a "credit spread" token
        if (optionType == TokenType.CALL_SPREAD && (tokenShortStrike < tokenLongStrike)) revert InvalidTokenId();
        if (optionType == TokenType.PUT_SPREAD && (tokenShortStrike > tokenLongStrike)) revert InvalidTokenId();

        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // minting a short
            if (account.shortCallId == 0) account.shortCallId = tokenId;
            else if (account.shortCallId != tokenId) revert InvalidTokenId();
            account.shortCallAmount += amount;
        } else {
            // minting a put or put spread
            if (account.shortPutId == 0) account.shortPutId = tokenId;
            else if (account.shortPutId != tokenId) revert InvalidTokenId();
            account.shortPutAmount += amount;
        }
    }

    function burnOption(
        Account memory account,
        uint256 tokenId,
        uint64 amount
    ) internal pure {
        TokenType optionType = OptionTokenUtils.parseTokenType(tokenId);
        if (optionType == TokenType.CALL || optionType == TokenType.CALL_SPREAD) {
            // burnning a call or call spread
            if (account.shortCallId != tokenId) revert InvalidTokenId();
            account.shortCallAmount -= amount;
            if (account.shortCallAmount == 0) account.shortCallId = 0;
        } else {
            // minting a put or put spread
            if (account.shortPutId != tokenId) revert InvalidTokenId();
            account.shortPutAmount -= amount;
            if (account.shortPutAmount == 0) account.shortPutId = 0;
        }
    }

    ///@dev merge an OptionToken into the accunt, changing existing short to spread
    function merge(Account memory account, bytes memory _data) internal {}

    ///@dev split an MarginAccount with spread into short + long
    function split(Account memory account, bytes memory _data) internal {}
}
