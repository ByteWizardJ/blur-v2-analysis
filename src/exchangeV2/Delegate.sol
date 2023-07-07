// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721 } from "lib/solmate/src/tokens/ERC721.sol";
import { ERC1155 } from "lib/solmate/src/tokens/ERC1155.sol";
import { ERC20 } from "lib/solmate/src/tokens/ERC20.sol";

import "./lib/Constants.sol";
import { AssetType, OrderType, Transfer } from "./lib/Structs.sol";

contract Delegate {
    error Unauthorized();
    error InvalidLength();

    address private immutable _EXCHANGE;

    constructor(address exchange) {
        _EXCHANGE = exchange;
    }

    modifier onlyApproved() {
        if (msg.sender != _EXCHANGE) {
            revert Unauthorized();
        }
        _;
    }

    function transfer(
        address taker,
        OrderType orderType,
        Transfer[] calldata transfers,
        uint256 length
    ) external onlyApproved returns (bool[] memory successful) {
        if (transfers.length < length) {
            revert InvalidLength();
        }
        successful = new bool[](length);

        for (uint256 i; i < length; ) {
            assembly {
                let calldataPointer := mload(0x40)
                let transfersPointer := add(transfers.offset, mul(Transfer_size, i))

                let assetType := calldataload(add(transfersPointer, Transfer_assetType_offset))
                switch assetType
                case 0 {
                    // AssetType_ERC721
                    mstore(calldataPointer, ERC721_safeTransferFrom_selector)
                    switch orderType
                    case 0 {
                        // OrderType_ASK; taker is recipient
                        mstore(add(calldataPointer, ERC721_safeTransferFrom_to_offset), taker)
                        mstore(
                            add(calldataPointer, ERC721_safeTransferFrom_from_offset),
                            calldataload(add(transfersPointer, Transfer_trader_offset))
                        )
                    }
                    case 1 {
                        // OrderType_BID; taker is sender
                        mstore(add(calldataPointer, ERC721_safeTransferFrom_from_offset), taker)
                        mstore(
                            add(calldataPointer, ERC721_safeTransferFrom_to_offset),
                            calldataload(add(transfersPointer, Transfer_trader_offset))
                        )
                    }
                    default {
                        revert(0, 0)
                    }

                    mstore(
                        add(calldataPointer, ERC721_safeTransferFrom_id_offset),
                        calldataload(add(transfersPointer, Transfer_id_offset))
                    )
                    let collection := calldataload(
                        add(transfersPointer, Transfer_collection_offset)
                    )
                    let success := call(
                        gas(),
                        collection,
                        0,
                        calldataPointer,
                        ERC721_safeTransferFrom_size,
                        0,
                        0
                    )
                    mstore(add(add(successful, 0x20), mul(0x20, i)), success)
                }
                case 1 {
                    // AssetType_ERC1155
                    mstore(calldataPointer, ERC1155_safeTransferFrom_selector)
                    switch orderType
                    case 0 {
                        // OrderType_ASK; taker is recipient
                        mstore(
                            add(calldataPointer, ERC1155_safeTransferFrom_from_offset),
                            calldataload(
                                add(
                                    transfersPointer,
                                    Transfer_trader_offset
                                )
                            )
                        )
                        mstore(add(calldataPointer, ERC1155_safeTransferFrom_to_offset), taker)
                    }
                    case 1 {
                        // OrderType_BID; taker is sender
                        mstore(
                            add(calldataPointer, ERC1155_safeTransferFrom_to_offset),
                            calldataload(
                                add(
                                    transfersPointer,
                                    Transfer_trader_offset
                                )
                            )
                        )
                        mstore(add(calldataPointer, ERC1155_safeTransferFrom_from_offset), taker)
                    }
                    default {
                        revert(0, 0)
                    }

                    mstore(add(calldataPointer, ERC1155_safeTransferFrom_data_pointer_offset), 0xa0)
                    mstore(add(calldataPointer, ERC1155_safeTransferFrom_data_offset), 0)
                    mstore(
                        add(calldataPointer, ERC1155_safeTransferFrom_id_offset),
                        calldataload(
                            add(transfersPointer, Transfer_id_offset)
                        )
                    )
                    mstore(
                        add(calldataPointer, ERC1155_safeTransferFrom_amount_offset),
                        calldataload(
                            add(
                                transfersPointer,
                                Transfer_amount_offset
                            )
                        )
                    )
                    let collection := calldataload(
                        add(
                            transfersPointer,
                            Transfer_collection_offset
                        )
                    )
                    let success := call(
                        gas(),
                        collection,
                        0,
                        calldataPointer,
                        ERC1155_safeTransferFrom_size,
                        0,
                        0
                    )
                    mstore(add(add(successful, 0x20), mul(0x20, i)), success)
                }
                default {
                    revert(0, 0)
                }
            }
            unchecked {
                ++i;
            }
        }
    }
}
