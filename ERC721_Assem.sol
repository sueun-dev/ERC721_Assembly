// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;
//string -> hex -> ascii

abstract contract ERC721 {


    // keccak("name")
    uint256 constant NAME_SLOT = 0xb4deace9b1788ce1b03518da303be35696899d14b9f97084f0acb409d7135d4f;

    // Should not be used for anything other than display purposes, 
    // it will break memory
    function name() external view returns (string memory) {
        assembly {
            mstore(0x20, 0x20)
            let nameBytes := sload(NAME_SLOT)
            let nameLength
            for { let i := 0 } lt(i, 32) { i := add(i, 1) }
            {
                if iszero(shl(mul(add(i, 1), 0x08), nameBytes)) {
                    nameLength := add(i, 1)
                    break
                }
            }
            // fuck memory safety, all my homies hate memory safety
            mstore(0x60, nameBytes)
            mstore8(0x5f, nameLength)
            return(0x20, 0x60)
        }
    }

    // keccak("symbol")
    uint256 constant SYMBOL_SLOT = 0x7d69ccd04f2a4cdb55d8c11fc025a501f1d8824144c5020daba01cb5bd77c117;

    // Should not be used for anything other than display purposes, 
    // it will break memory
    function symbol() external view returns (string memory) {
        assembly {
            mstore(0x20, 0x20)
            let symbolBytes := sload(SYMBOL_SLOT)
            let symbolLength
            for { let i := 0 } lt(i, 32) { i := add(i, 1) }
            {
                if iszero(shl(mul(add(i, 1), 0x08), symbolBytes)) { 
                    symbolLength := add(i, 1)
                    break
                }
            }
            // fuck memory safety, all my homies hate memory safety
            mstore(0x60, symbolBytes)
            mstore8(0x5f, symbolLength)
            return(0x20, 0x60)
        }
    }

    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*//////////////////////////////////////////////////////////////
                      ERC721 BALANCE/OWNER STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 constant OWNER_OF_START_SLOT = 0x1000;
    uint256 constant MAX_ID = 0xFFFEFFF;

    //         OWNEROF STORAGE
    // ===================================
    // Slot: 0x1000 + id (4096 + id)
    // Lower bound: 0x1000 (4096)
    // Upper bound: 0xFFFFFFF (268435455)
    // Max size: 0xFFFEFFF (268431359)
    // ===================================

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        assembly {
            owner := sload(add(OWNER_OF_START_SLOT, id))

            // require(owner != address(0), "NOT_MINTED");
            if iszero(owner) {
                // 0x4E4F545F4D494E544544: "NOT_MINTED"
                mstore(0x00, 0x4E4F545F4D494E544544)
                revert(0x16, 0x0a)
            }
        }
    }

    uint256 constant BALANCE_OF_SLOT_SHIFT = 96;

    //                      BALANCEOF STORAGE
    // ==================================================================
    // Slot: Owner address << 96, e.g. 
    // 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef000000000000000000000000
    // ==================================================================

    function balanceOf(address owner) public view virtual returns (uint256 _balance) {
        assembly {
            // require(owner != address(0), "ZERO_ADDRESS");
            if iszero(owner) {
                // 0x4E4F545F4D494E544544: "NOT_MINTED"
                mstore(0x00, 0x5A45524F5F41444452455353)
                revert(0x14, 0x0c)
            }

            _balance := sload(shl(BALANCE_OF_SLOT_SHIFT, owner))
        }
    }

    /*//////////////////////////////////////////////////////////////
                         ERC721 APPROVAL STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 constant GET_APPROVED_START_SLOT = 0x10000000;

    //         GETAPPROVED STORAGE
    // ======================================
    // Slot: 0x10000000 + id (268435456 + id)
    // Lower bound: 0x10000000 (268435456)
    // Upper bound: 0x1FFFEFFF (536866815)
    // ======================================

    function getApproved(uint256 id) public view returns (address approved) {
        assembly {
            approved := sload(add(GET_APPROVED_START_SLOT, id))
        }
    }

    //          ISAPPROVEDFORALL STORAGE
    // ============================================
    // Slot: keccak(address owner, address spender)
    // ============================================

    function isApprovedForAll(address owner, address spender) public view returns (bool approvedForAll) {
        assembly {
            mstore(0x00, owner)
            mstore(0x20, spender)
            approvedForAll := sload(keccak256(0x00, 0x40))
        }
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    // Params must be: (name, symbol), in that order
    constructor(string memory, string memory) {
        assembly {
            let fmp := mload(0x40)
            sstore(NAME_SLOT, mload(sub(fmp, 0x60)))
            sstore(SYMBOL_SLOT, mload(sub(fmp, 0x20)))
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC721 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 id) public virtual {
        assembly {
            let owner := sload(add(OWNER_OF_START_SLOT, id))

            // require(msg.sender == owner || isApprovedForAll[owner][msg.sender], "NOT_AUTHORIZED");
            if iszero(eq(caller(), owner)) {
                mstore(0x00, owner)
                mstore(0x20, caller())
                if iszero(sload(keccak256(0x00, 0x40))) {
                    // 0x4E4F545F415554484F52495A4544: "NOT_AUTHORIZED"
                    mstore(0x00, 0x4E4F545F415554484F52495A4544)
                    revert(0x12, 0x0E)
                }
            }

            // Set approval
            // Slot overwrite attack impossible because of owner check above
            sstore(add(GET_APPROVED_START_SLOT, id), spender)
            
            // emit Approval(owner, spender, id);
            log4(
                0,
                0,
                0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925,
                owner,
                spender,
                id
            )
        }
    }

    function setApprovalForAll(address operator, bool approved) public virtual {
        assembly {
            // Set approval for all
            mstore(0x00, caller())
            mstore(0x20, operator)
            sstore(keccak256(0x00, 0x40), approved)

            // emit ApprovalForAll(msg.sender, operator, approved);
            log4(
                0,
                0,
                0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31,
                caller(),
                operator,
                approved
            )
        }
    }

    function transferFrom(
        address from,
        address to,
        uint256 id
    ) public virtual {
        assembly {
            // require(from == ownerOf[id], "WRONG_FROM");
            if iszero(eq(from, sload(add(OWNER_OF_START_SLOT, id)))) {
                // 0x57524F4E475F46524F4D: "WRONG_FROM"
                mstore(0x00, 0x57524F4E475F46524F4D)
                revert(0xB0, 0x0A)
            }

            // require(to != address(0), "INVALID_RECIPIENT");
            if iszero(to) {
                // 0x494E56414C49445F524543495049454E54: "INVALID_RECIPIENT"
                mstore(0x00, 0x494E56414C49445F524543495049454E54)
                revert(0x0F, 0x11)
            }

            // require(
            //     msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id],
            //     "NOT_AUTHORIZED"
            // );
            mstore(0x00, from)
            mstore(0x20, caller())
            // TODO: Try short circuiting
            if iszero(or(eq(caller(), from), or(sload(keccak256(0x00, 0x40)), sload(add(GET_APPROVED_START_SLOT, id))))) {
                // 0x4E4F545F415554484F52495A4544: "NOT_AUTHORIZED"
                mstore(0x00, 0x4E4F545F415554484F52495A4544)
                revert(0x12, 0x0E)
            }

            // Underflow of the sender's balance is impossible because we check for
            // ownership above and the recipient's balance can't realistically overflow.

            // Decrement from balance
            sstore(shl(BALANCE_OF_SLOT_SHIFT, from), sub(sload(shl(BALANCE_OF_SLOT_SHIFT, from)), 1))
            // Increment to balance
            sstore(shl(BALANCE_OF_SLOT_SHIFT, to), add(sload(shl(BALANCE_OF_SLOT_SHIFT, to)), 1))

            // Set to address as owner
            // Slot overwrite attack impossible because of owner check above
            sstore(add(OWNER_OF_START_SLOT, id), to)

            // Set approved to zero address
            // Slot overwrite attack impossible because of owner check above
            sstore(add(GET_APPROVED_START_SLOT, id), 0)

            // emit Transfer(from, to, id);
            log4(
                0,
                0,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                from,
                to,
                id
            )
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ERC165 LOGIC
    //////////////////////////////////////////////////////////////*/

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool result) {
        assembly {
            result := or(
                // ERC165 Interface ID for ERC165
                eq(interfaceId, 0x01ffc9a7), 
                or(
                    // ERC165 Interface ID for ERC721
                    eq(interfaceId, 0x80ac58cd), 
                    // ERC165 Interface ID for ERC721Metadata
                    eq(interfaceId, 0x5b5e139f)
                )
            )
        }
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 id) internal virtual {
        assembly {
            // require(to != address(0), "INVALID_RECIPIENT");
            if iszero(to) {
                // 0x494E56414C49445F524543495049454E54: "INVALID_RECIPIENT"
                mstore(0x00, 0x494E56414C49445F524543495049454E54)
                revert(0x0F, 0x11)
            }

            // require(ownerOf[id] == address(0), "ALREADY_MINTED");
            if iszero(iszero(sload(add(OWNER_OF_START_SLOT, id)))) {
                // 0x414C52454144595F4D494E544544: "ALREADY_MINTED"
                mstore(0x00, 0x414C52454144595F4D494E544544)
                revert(0x12, 0x0E)
            }

            // Prevent attacker from overwriting a non-ownerOf storage slot by bounding id
            if gt(id, MAX_ID) {
                // 0x455843454544535F55505045525F424F554E44: "EXCEEDS_UPPER_BOUND"
                mstore(0x00, 0x455843454544535F55505045525F424F554E44)
                revert(0x0D, 0x13)
            }

            // Increment balance of recipient
            // Counter overflow is incredibly unrealistic.
            sstore(shl(BALANCE_OF_SLOT_SHIFT, to), add(sload(shl(BALANCE_OF_SLOT_SHIFT, to)), 1))

            // Set ownerOf
            // Slot overwrite attack impossible because of owner check above along with bounded id
            sstore(add(OWNER_OF_START_SLOT, id), to)

            // emit Transfer(address(0), to, id);
            log4(
                0,
                0,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                0,
                to,
                id
            )
        }
    }

    function _burn(uint256 id) internal virtual {
        assembly {
            let owner := sload(add(OWNER_OF_START_SLOT, id))

            // require(owner != address(0), "NOT_MINTED");
            if iszero(owner) {
                // 0x4E4F545F4D494E544544: "NOT_MINTED"
                mstore(0x00, 0x4E4F545F4D494E544544)
                revert(0x16, 0x0a)
            }

            // Decrement balance of recipient
            // Ownership check above ensures no underflow.
            sstore(shl(BALANCE_OF_SLOT_SHIFT, owner), sub(sload(shl(BALANCE_OF_SLOT_SHIFT, owner)), 1))

            // Set owner to zero address
            // Slot overwrite attack impossible because of owner check above along with bounded id
            sstore(add(OWNER_OF_START_SLOT, id), 0)

            // Clear approval
            // Slot overwrite attack impossible because of owner check above along with bounded id
            sstore(add(GET_APPROVED_START_SLOT, id), 0)

            // emit Transfer(owner, address(0), id);
            log4(
                0,
                0,
                0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef,
                owner,
                0,
                id
            )
        }
    }
}

/// @notice A generic interface for a contract which properly accepts ERC721 tokens.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC721.sol)
abstract contract ERC721TokenReceiver {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC721TokenReceiver.onERC721Received.selector;
    }
}
