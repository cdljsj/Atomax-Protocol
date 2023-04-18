// Sources flattened with hardhat v2.13.0 https://hardhat.org

// File @zondax/filecoin-solidity/contracts/v0.8/types/CommonTypes.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING

// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

/// @title Filecoin actors' common types for Solidity.
/// @author Zondax AG
library CommonTypes {
    uint constant UniversalReceiverHookMethodNum = 3726118371;

    /// @param idx index for the failure in batch
    /// @param code failure code
    struct FailCode {
        uint32 idx;
        uint32 code;
    }

    /// @param success_count total successes in batch
    /// @param fail_codes list of failures code and index for each failure in batch
    struct BatchReturn {
        uint32 success_count;
        FailCode[] fail_codes;
    }

    /// @param type_ asset type
    /// @param payload payload corresponding to asset type
    struct UniversalReceiverParams {
        uint32 type_;
        bytes payload;
    }

    /// @param val contains the actual arbitrary number written as binary
    /// @param neg indicates if val is negative or not
    struct BigInt {
        bytes val;
        bool neg;
    }

    /// @param data filecoin address in bytes format
    struct FilAddress {
        bytes data;
    }

    /// @param data cid in bytes format
    struct Cid {
        bytes data;
    }

    /// @param dataBytes deal proposal label in bytes format (it can be utf8 string or arbitrary bytes string). If both are empty, its default value will be empty bytes.
    struct DealLabel {
        bytes dataBts;
        string dataStr;
    }

    type FilActorId is uint64;
}


// File @zondax/filecoin-solidity/contracts/v0.8/cbor/BigIntCbor.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;

/// @title This library is a set of functions meant to handle CBOR serialization and deserialization for BigInt type
/// @author Zondax AG
library BigIntCBOR {
    /// @notice serialize BigInt instance to bytes
    /// @param num BigInt instance to serialize
    /// @return serialized BigInt as bytes
    function serializeBigInt(CommonTypes.BigInt memory num) internal pure returns (bytes memory) {
        bytes memory raw = new bytes(num.val.length + 1);

        raw[0] = num.neg == true ? bytes1(0x01) : bytes1(0x00);

        uint index = 1;
        for (uint i = 0; i < num.val.length; i++) {
            raw[index] = num.val[i];
            index++;
        }

        return raw;
    }

    /// @notice deserialize big int (encoded as bytes) to BigInt instance
    /// @param raw as bytes to parse
    /// @return parsed BigInt instance
    function deserializeBigInt(bytes memory raw) internal pure returns (CommonTypes.BigInt memory) {
        if (raw.length == 0) {
            return CommonTypes.BigInt(hex"00", false);
        }

        bytes memory val = new bytes(raw.length - 1);
        bool neg = false;

        if (raw[0] == 0x01) {
            neg = true;
        }

        for (uint i = 1; i < raw.length; i++) {
            val[i - 1] = raw[i];
        }

        return CommonTypes.BigInt(val, neg);
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/utils/CborDecode.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;

// 	MajUnsignedInt = 0
// 	MajSignedInt   = 1
// 	MajByteString  = 2
// 	MajTextString  = 3
// 	MajArray       = 4
// 	MajMap         = 5
// 	MajTag         = 6
// 	MajOther       = 7

uint8 constant MajUnsignedInt = 0;
uint8 constant MajSignedInt = 1;
uint8 constant MajByteString = 2;
uint8 constant MajTextString = 3;
uint8 constant MajArray = 4;
uint8 constant MajMap = 5;
uint8 constant MajTag = 6;
uint8 constant MajOther = 7;

uint8 constant TagTypeBigNum = 2;
uint8 constant TagTypeNegativeBigNum = 3;

uint8 constant True_Type = 21;
uint8 constant False_Type = 20;

/// @notice This library is a set a functions that allows anyone to decode cbor encoded bytes
/// @dev methods in this library try to read the data type indicated from cbor encoded data stored in bytes at a specific index
/// @dev if it successes, methods will return the read value and the new index (intial index plus read bytes)
/// @author Zondax AG
library CBORDecoder {
    /// @notice check if next value on the cbor encoded data is null
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    function isNullNext(bytes memory cborData, uint byteIdx) internal pure returns (bool) {
        return cborData[byteIdx] == hex"f6";
    }

    /// @notice attempt to read a bool value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return a bool decoded from input bytes and the byte index after moving past the value
    function readBool(bytes memory cborData, uint byteIdx) internal pure returns (bool, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajOther, "invalid maj (expected MajOther)");
        assert(value == True_Type || value == False_Type);

        return (value != False_Type, byteIdx);
    }

    /// @notice attempt to read the length of a fixed array
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return length of the fixed array decoded from input bytes and the byte index after moving past the value
    function readFixedArray(bytes memory cborData, uint byteIdx) internal pure returns (uint, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajArray, "invalid maj (expected MajArray)");

        return (len, byteIdx);
    }

    /// @notice attempt to read an arbitrary length string value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return arbitrary length string decoded from input bytes and the byte index after moving past the value
    function readString(bytes memory cborData, uint byteIdx) internal pure returns (string memory, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajTextString, "invalid maj (expected MajTextString)");

        uint max_len = byteIdx + len;
        bytes memory slice = new bytes(len);
        uint slice_index = 0;
        for (uint256 i = byteIdx; i < max_len; i++) {
            slice[slice_index] = cborData[i];
            slice_index++;
        }

        return (string(slice), byteIdx + len);
    }

    /// @notice attempt to read an arbitrary byte string value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return arbitrary byte string decoded from input bytes and the byte index after moving past the value
    function readBytes(bytes memory cborData, uint byteIdx) internal pure returns (bytes memory, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajTag || maj == MajByteString, "invalid maj (expected MajTag or MajByteString)");

        if (maj == MajTag) {
            (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
            assert(maj == MajByteString);
        }

        uint max_len = byteIdx + len;
        bytes memory slice = new bytes(len);
        uint slice_index = 0;
        for (uint256 i = byteIdx; i < max_len; i++) {
            slice[slice_index] = cborData[i];
            slice_index++;
        }

        return (slice, byteIdx + len);
    }

    /// @notice attempt to read a bytes32 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return a bytes32 decoded from input bytes and the byte index after moving past the value
    function readBytes32(bytes memory cborData, uint byteIdx) internal pure returns (bytes32, uint) {
        uint8 maj;
        uint len;

        (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajByteString, "invalid maj (expected MajByteString)");

        uint max_len = byteIdx + len;
        bytes memory slice = new bytes(32);
        uint slice_index = 32 - len;
        for (uint256 i = byteIdx; i < max_len; i++) {
            slice[slice_index] = cborData[i];
            slice_index++;
        }

        return (bytes32(slice), byteIdx + len);
    }

    /// @notice attempt to read a uint256 value encoded per cbor specification
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint256 decoded from input bytes and the byte index after moving past the value
    function readUInt256(bytes memory cborData, uint byteIdx) internal pure returns (uint256, uint) {
        uint8 maj;
        uint256 value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajTag || maj == MajUnsignedInt, "invalid maj (expected MajTag or MajUnsignedInt)");

        if (maj == MajTag) {
            require(value == TagTypeBigNum, "invalid tag (expected TagTypeBigNum)");

            uint len;
            (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
            require(maj == MajByteString, "invalid maj (expected MajByteString)");

            require(cborData.length >= byteIdx + len, "slicing out of range");
            assembly {
                value := mload(add(cborData, add(len, byteIdx)))
            }

            return (value, byteIdx + len);
        }

        return (value, byteIdx);
    }

    /// @notice attempt to read a int256 value encoded per cbor specification
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int256 decoded from input bytes and the byte index after moving past the value
    function readInt256(bytes memory cborData, uint byteIdx) internal pure returns (int256, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajTag || maj == MajSignedInt, "invalid maj (expected MajTag or MajSignedInt)");

        if (maj == MajTag) {
            assert(value == TagTypeNegativeBigNum);

            uint len;
            (maj, len, byteIdx) = parseCborHeader(cborData, byteIdx);
            require(maj == MajByteString, "invalid maj (expected MajByteString)");

            require(cborData.length >= byteIdx + len, "slicing out of range");
            assembly {
                value := mload(add(cborData, add(len, byteIdx)))
            }

            return (int256(value), byteIdx + len);
        }

        return (int256(value), byteIdx);
    }

    /// @notice attempt to read a uint64 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint64 decoded from input bytes and the byte index after moving past the value
    function readUInt64(bytes memory cborData, uint byteIdx) internal pure returns (uint64, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint64(value), byteIdx);
    }

    /// @notice attempt to read a uint32 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint32 decoded from input bytes and the byte index after moving past the value
    function readUInt32(bytes memory cborData, uint byteIdx) internal pure returns (uint32, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint32(value), byteIdx);
    }

    /// @notice attempt to read a uint16 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint16 decoded from input bytes and the byte index after moving past the value
    function readUInt16(bytes memory cborData, uint byteIdx) internal pure returns (uint16, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint16(value), byteIdx);
    }

    /// @notice attempt to read a uint8 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an uint8 decoded from input bytes and the byte index after moving past the value
    function readUInt8(bytes memory cborData, uint byteIdx) internal pure returns (uint8, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajUnsignedInt, "invalid maj (expected MajUnsignedInt)");

        return (uint8(value), byteIdx);
    }

    /// @notice attempt to read a int64 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int64 decoded from input bytes and the byte index after moving past the value
    function readInt64(bytes memory cborData, uint byteIdx) internal pure returns (int64, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajSignedInt || maj == MajUnsignedInt, "invalid maj (expected MajSignedInt or MajUnsignedInt)");

        return (int64(uint64(value)), byteIdx);
    }

    /// @notice attempt to read a int32 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int32 decoded from input bytes and the byte index after moving past the value
    function readInt32(bytes memory cborData, uint byteIdx) internal pure returns (int32, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajSignedInt || maj == MajUnsignedInt, "invalid maj (expected MajSignedInt or MajUnsignedInt)");

        return (int32(uint32(value)), byteIdx);
    }

    /// @notice attempt to read a int16 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int16 decoded from input bytes and the byte index after moving past the value
    function readInt16(bytes memory cborData, uint byteIdx) internal pure returns (int16, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajSignedInt || maj == MajUnsignedInt, "invalid maj (expected MajSignedInt or MajUnsignedInt)");

        return (int16(uint16(value)), byteIdx);
    }

    /// @notice attempt to read a int8 value
    /// @param cborData cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return an int8 decoded from input bytes and the byte index after moving past the value
    function readInt8(bytes memory cborData, uint byteIdx) internal pure returns (int8, uint) {
        uint8 maj;
        uint value;

        (maj, value, byteIdx) = parseCborHeader(cborData, byteIdx);
        require(maj == MajSignedInt || maj == MajUnsignedInt, "invalid maj (expected MajSignedInt or MajUnsignedInt)");

        return (int8(uint8(value)), byteIdx);
    }

    /// @notice slice uint8 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint8 sliced from bytes
    function sliceUInt8(bytes memory bs, uint start) internal pure returns (uint8) {
        require(bs.length >= start + 1, "slicing out of range");
        return uint8(bs[start]);
    }

    /// @notice slice uint16 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint16 sliced from bytes
    function sliceUInt16(bytes memory bs, uint start) internal pure returns (uint16) {
        require(bs.length >= start + 2, "slicing out of range");
        bytes2 x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return uint16(x);
    }

    /// @notice slice uint32 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint32 sliced from bytes
    function sliceUInt32(bytes memory bs, uint start) internal pure returns (uint32) {
        require(bs.length >= start + 4, "slicing out of range");
        bytes4 x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return uint32(x);
    }

    /// @notice slice uint64 from bytes starting at a given index
    /// @param bs bytes to slice from
    /// @param start current position to slice from bytes
    /// @return uint64 sliced from bytes
    function sliceUInt64(bytes memory bs, uint start) internal pure returns (uint64) {
        require(bs.length >= start + 8, "slicing out of range");
        bytes8 x;
        assembly {
            x := mload(add(bs, add(0x20, start)))
        }
        return uint64(x);
    }

    /// @notice Parse cbor header for major type and extra info.
    /// @param cbor cbor encoded bytes to parse from
    /// @param byteIndex current position to read on the cbor encoded bytes
    /// @return major type, extra info and the byte index after moving past header bytes
    function parseCborHeader(bytes memory cbor, uint byteIndex) internal pure returns (uint8, uint64, uint) {
        uint8 first = sliceUInt8(cbor, byteIndex);
        byteIndex += 1;
        uint8 maj = (first & 0xe0) >> 5;
        uint8 low = first & 0x1f;
        // We don't handle CBOR headers with extra > 27, i.e. no indefinite lengths
        require(low < 28, "cannot handle headers with extra > 27");

        // extra is lower bits
        if (low < 24) {
            return (maj, low, byteIndex);
        }

        // extra in next byte
        if (low == 24) {
            uint8 next = sliceUInt8(cbor, byteIndex);
            byteIndex += 1;
            require(next >= 24, "invalid cbor"); // otherwise this is invalid cbor
            return (maj, next, byteIndex);
        }

        // extra in next 2 bytes
        if (low == 25) {
            uint16 extra16 = sliceUInt16(cbor, byteIndex);
            byteIndex += 2;
            return (maj, extra16, byteIndex);
        }

        // extra in next 4 bytes
        if (low == 26) {
            uint32 extra32 = sliceUInt32(cbor, byteIndex);
            byteIndex += 4;
            return (maj, extra32, byteIndex);
        }

        // extra in next 8 bytes
        assert(low == 27);
        uint64 extra64 = sliceUInt64(cbor, byteIndex);
        byteIndex += 8;
        return (maj, extra64, byteIndex);
    }
}


// File @ensdomains/buffer/contracts/Buffer.sol@v0.1.0


pragma solidity ^0.8.4;

/**
* @dev A library for working with mutable byte buffers in Solidity.
*
* Byte buffers are mutable and expandable, and provide a variety of primitives
* for appending to them. At any time you can fetch a bytes object containing the
* current contents of the buffer. The bytes object should not be stored between
* operations, as it may change due to resizing of the buffer.
*/
library Buffer {
    /**
    * @dev Represents a mutable buffer. Buffers have a current value (buf) and
    *      a capacity. The capacity may be longer than the current value, in
    *      which case it can be extended without the need to allocate more memory.
    */
    struct buffer {
        bytes buf;
        uint capacity;
    }

    /**
    * @dev Initializes a buffer with an initial capacity.
    * @param buf The buffer to initialize.
    * @param capacity The number of bytes of space to allocate the buffer.
    * @return The buffer, for chaining.
    */
    function init(buffer memory buf, uint capacity) internal pure returns(buffer memory) {
        if (capacity % 32 != 0) {
            capacity += 32 - (capacity % 32);
        }
        // Allocate space for the buffer data
        buf.capacity = capacity;
        assembly {
            let ptr := mload(0x40)
            mstore(buf, ptr)
            mstore(ptr, 0)
            let fpm := add(32, add(ptr, capacity))
            if lt(fpm, ptr) {
                revert(0, 0)
            }
            mstore(0x40, fpm)
        }
        return buf;
    }

    /**
    * @dev Initializes a new buffer from an existing bytes object.
    *      Changes to the buffer may mutate the original value.
    * @param b The bytes object to initialize the buffer with.
    * @return A new buffer.
    */
    function fromBytes(bytes memory b) internal pure returns(buffer memory) {
        buffer memory buf;
        buf.buf = b;
        buf.capacity = b.length;
        return buf;
    }

    function resize(buffer memory buf, uint capacity) private pure {
        bytes memory oldbuf = buf.buf;
        init(buf, capacity);
        append(buf, oldbuf);
    }

    /**
    * @dev Sets buffer length to 0.
    * @param buf The buffer to truncate.
    * @return The original buffer, for chaining..
    */
    function truncate(buffer memory buf) internal pure returns (buffer memory) {
        assembly {
            let bufptr := mload(buf)
            mstore(bufptr, 0)
        }
        return buf;
    }

    /**
    * @dev Appends len bytes of a byte string to a buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @param len The number of bytes to copy.
    * @return The original buffer, for chaining.
    */
    function append(buffer memory buf, bytes memory data, uint len) internal pure returns(buffer memory) {
        require(len <= data.length);

        uint off = buf.buf.length;
        uint newCapacity = off + len;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint dest;
        uint src;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Length of existing buffer data
            let buflen := mload(bufptr)
            // Start address = buffer address + offset + sizeof(buffer length)
            dest := add(add(bufptr, 32), off)
            // Update buffer length if we're extending it
            if gt(newCapacity, buflen) {
                mstore(bufptr, newCapacity)
            }
            src := add(data, 32)
        }

        // Copy word-length chunks while possible
        for (; len >= 32; len -= 32) {
            assembly {
                mstore(dest, mload(src))
            }
            dest += 32;
            src += 32;
        }

        // Copy remaining bytes
        unchecked {
            uint mask = (256 ** (32 - len)) - 1;
            assembly {
                let srcpart := and(mload(src), not(mask))
                let destpart := and(mload(dest), mask)
                mstore(dest, or(destpart, srcpart))
            }
        }

        return buf;
    }

    /**
    * @dev Appends a byte string to a buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chaining.
    */
    function append(buffer memory buf, bytes memory data) internal pure returns (buffer memory) {
        return append(buf, data, data.length);
    }

    /**
    * @dev Appends a byte to the buffer. Resizes if doing so would exceed the
    *      capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chaining.
    */
    function appendUint8(buffer memory buf, uint8 data) internal pure returns(buffer memory) {
        uint off = buf.buf.length;
        uint offPlusOne = off + 1;
        if (off >= buf.capacity) {
            resize(buf, offPlusOne * 2);
        }

        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + off
            let dest := add(add(bufptr, off), 32)
            mstore8(dest, data)
            // Update buffer length if we extended it
            if gt(offPlusOne, mload(bufptr)) {
                mstore(bufptr, offPlusOne)
            }
        }

        return buf;
    }

    /**
    * @dev Appends len bytes of bytes32 to a buffer. Resizes if doing so would
    *      exceed the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @param len The number of bytes to write (left-aligned).
    * @return The original buffer, for chaining.
    */
    function append(buffer memory buf, bytes32 data, uint len) private pure returns(buffer memory) {
        uint off = buf.buf.length;
        uint newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        unchecked {
            uint mask = (256 ** len) - 1;
            // Right-align data
            data = data >> (8 * (32 - len));
            assembly {
                // Memory address of the buffer data
                let bufptr := mload(buf)
                // Address = buffer address + sizeof(buffer length) + newCapacity
                let dest := add(bufptr, newCapacity)
                mstore(dest, or(and(mload(dest), not(mask)), data))
                // Update buffer length if we extended it
                if gt(newCapacity, mload(bufptr)) {
                    mstore(bufptr, newCapacity)
                }
            }
        }
        return buf;
    }

    /**
    * @dev Appends a bytes20 to the buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chhaining.
    */
    function appendBytes20(buffer memory buf, bytes20 data) internal pure returns (buffer memory) {
        return append(buf, bytes32(data), 20);
    }

    /**
    * @dev Appends a bytes32 to the buffer. Resizes if doing so would exceed
    *      the capacity of the buffer.
    * @param buf The buffer to append to.
    * @param data The data to append.
    * @return The original buffer, for chaining.
    */
    function appendBytes32(buffer memory buf, bytes32 data) internal pure returns (buffer memory) {
        return append(buf, data, 32);
    }

    /**
     * @dev Appends a byte to the end of the buffer. Resizes if doing so would
     *      exceed the capacity of the buffer.
     * @param buf The buffer to append to.
     * @param data The data to append.
     * @param len The number of bytes to write (right-aligned).
     * @return The original buffer.
     */
    function appendInt(buffer memory buf, uint data, uint len) internal pure returns(buffer memory) {
        uint off = buf.buf.length;
        uint newCapacity = len + off;
        if (newCapacity > buf.capacity) {
            resize(buf, newCapacity * 2);
        }

        uint mask = (256 ** len) - 1;
        assembly {
            // Memory address of the buffer data
            let bufptr := mload(buf)
            // Address = buffer address + sizeof(buffer length) + newCapacity
            let dest := add(bufptr, newCapacity)
            mstore(dest, or(and(mload(dest), not(mask)), data))
            // Update buffer length if we extended it
            if gt(newCapacity, mload(bufptr)) {
                mstore(bufptr, newCapacity)
            }
        }
        return buf;
    }
}


// File solidity-cborutils/contracts/CBOR.sol@v2.0.0


pragma solidity ^0.8.4;

/**
* @dev A library for populating CBOR encoded payload in Solidity.
*
* https://datatracker.ietf.org/doc/html/rfc7049
*
* The library offers various write* and start* methods to encode values of different types.
* The resulted buffer can be obtained with data() method.
* Encoding of primitive types is staightforward, whereas encoding of sequences can result
* in an invalid CBOR if start/write/end flow is violated.
* For the purpose of gas saving, the library does not verify start/write/end flow internally,
* except for nested start/end pairs.
*/

library CBOR {
    using Buffer for Buffer.buffer;

    struct CBORBuffer {
        Buffer.buffer buf;
        uint256 depth;
    }

    uint8 private constant MAJOR_TYPE_INT = 0;
    uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
    uint8 private constant MAJOR_TYPE_BYTES = 2;
    uint8 private constant MAJOR_TYPE_STRING = 3;
    uint8 private constant MAJOR_TYPE_ARRAY = 4;
    uint8 private constant MAJOR_TYPE_MAP = 5;
    uint8 private constant MAJOR_TYPE_TAG = 6;
    uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

    uint8 private constant TAG_TYPE_BIGNUM = 2;
    uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;

    uint8 private constant CBOR_FALSE = 20;
    uint8 private constant CBOR_TRUE = 21;
    uint8 private constant CBOR_NULL = 22;
    uint8 private constant CBOR_UNDEFINED = 23;

    function create(uint256 capacity) internal pure returns(CBORBuffer memory cbor) {
        Buffer.init(cbor.buf, capacity);
        cbor.depth = 0;
        return cbor;
    }

    function data(CBORBuffer memory buf) internal pure returns(bytes memory) {
        require(buf.depth == 0, "Invalid CBOR");
        return buf.buf.buf;
    }

    function writeUInt256(CBORBuffer memory buf, uint256 value) internal pure {
        buf.buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_BIGNUM));
        writeBytes(buf, abi.encode(value));
    }

    function writeInt256(CBORBuffer memory buf, int256 value) internal pure {
        if (value < 0) {
            buf.buf.appendUint8(
                uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_NEGATIVE_BIGNUM)
            );
            writeBytes(buf, abi.encode(uint256(-1 - value)));
        } else {
            writeUInt256(buf, uint256(value));
        }
    }

    function writeUInt64(CBORBuffer memory buf, uint64 value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_INT, value);
    }

    function writeInt64(CBORBuffer memory buf, int64 value) internal pure {
        if(value >= 0) {
            writeFixedNumeric(buf, MAJOR_TYPE_INT, uint64(value));
        } else{
            writeFixedNumeric(buf, MAJOR_TYPE_NEGATIVE_INT, uint64(-1 - value));
        }
    }

    function writeBytes(CBORBuffer memory buf, bytes memory value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_BYTES, uint64(value.length));
        buf.buf.append(value);
    }

    function writeString(CBORBuffer memory buf, string memory value) internal pure {
        writeFixedNumeric(buf, MAJOR_TYPE_STRING, uint64(bytes(value).length));
        buf.buf.append(bytes(value));
    }

    function writeBool(CBORBuffer memory buf, bool value) internal pure {
        writeContentFree(buf, value ? CBOR_TRUE : CBOR_FALSE);
    }

    function writeNull(CBORBuffer memory buf) internal pure {
        writeContentFree(buf, CBOR_NULL);
    }

    function writeUndefined(CBORBuffer memory buf) internal pure {
        writeContentFree(buf, CBOR_UNDEFINED);
    }

    function startArray(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
        buf.depth += 1;
    }

    function startFixedArray(CBORBuffer memory buf, uint64 length) internal pure {
        writeDefiniteLengthType(buf, MAJOR_TYPE_ARRAY, length);
    }

    function startMap(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
        buf.depth += 1;
    }

    function startFixedMap(CBORBuffer memory buf, uint64 length) internal pure {
        writeDefiniteLengthType(buf, MAJOR_TYPE_MAP, length);
    }

    function endSequence(CBORBuffer memory buf) internal pure {
        writeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
        buf.depth -= 1;
    }

    function writeKVString(CBORBuffer memory buf, string memory key, string memory value) internal pure {
        writeString(buf, key);
        writeString(buf, value);
    }

    function writeKVBytes(CBORBuffer memory buf, string memory key, bytes memory value) internal pure {
        writeString(buf, key);
        writeBytes(buf, value);
    }

    function writeKVUInt256(CBORBuffer memory buf, string memory key, uint256 value) internal pure {
        writeString(buf, key);
        writeUInt256(buf, value);
    }

    function writeKVInt256(CBORBuffer memory buf, string memory key, int256 value) internal pure {
        writeString(buf, key);
        writeInt256(buf, value);
    }

    function writeKVUInt64(CBORBuffer memory buf, string memory key, uint64 value) internal pure {
        writeString(buf, key);
        writeUInt64(buf, value);
    }

    function writeKVInt64(CBORBuffer memory buf, string memory key, int64 value) internal pure {
        writeString(buf, key);
        writeInt64(buf, value);
    }

    function writeKVBool(CBORBuffer memory buf, string memory key, bool value) internal pure {
        writeString(buf, key);
        writeBool(buf, value);
    }

    function writeKVNull(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        writeNull(buf);
    }

    function writeKVUndefined(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        writeUndefined(buf);
    }

    function writeKVMap(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        startMap(buf);
    }

    function writeKVArray(CBORBuffer memory buf, string memory key) internal pure {
        writeString(buf, key);
        startArray(buf);
    }

    function writeFixedNumeric(
        CBORBuffer memory buf,
        uint8 major,
        uint64 value
    ) private pure {
        if (value <= 23) {
            buf.buf.appendUint8(uint8((major << 5) | value));
        } else if (value <= 0xFF) {
            buf.buf.appendUint8(uint8((major << 5) | 24));
            buf.buf.appendInt(value, 1);
        } else if (value <= 0xFFFF) {
            buf.buf.appendUint8(uint8((major << 5) | 25));
            buf.buf.appendInt(value, 2);
        } else if (value <= 0xFFFFFFFF) {
            buf.buf.appendUint8(uint8((major << 5) | 26));
            buf.buf.appendInt(value, 4);
        } else {
            buf.buf.appendUint8(uint8((major << 5) | 27));
            buf.buf.appendInt(value, 8);
        }
    }

    function writeIndefiniteLengthType(CBORBuffer memory buf, uint8 major)
        private
        pure
    {
        buf.buf.appendUint8(uint8((major << 5) | 31));
    }

    function writeDefiniteLengthType(CBORBuffer memory buf, uint8 major, uint64 length)
        private
        pure
    {
        writeFixedNumeric(buf, major, length);
    }

    function writeContentFree(CBORBuffer memory buf, uint8 value) private pure {
        buf.buf.appendUint8(uint8((MAJOR_TYPE_CONTENT_FREE << 5) | value));
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/cbor/BytesCbor.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;



/// @title This library is a set of functions meant to handle CBOR serialization and deserialization for bytes
/// @author Zondax AG
library BytesCBOR {
    using CBOR for CBOR.CBORBuffer;
    using CBORDecoder for bytes;
    using BigIntCBOR for bytes;

    /// @notice serialize raw bytes as cbor bytes string encoded
    /// @param data raw data in bytes
    /// @return encoded cbor bytes
    function serializeBytes(bytes memory data) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeBytes(data);

        return buf.data();
    }

    /// @notice serialize raw address (in bytes) as cbor bytes string encoded (how an address is passed to filecoin actors)
    /// @param addr raw address in bytes
    /// @return encoded address as cbor bytes
    function serializeAddress(bytes memory addr) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeBytes(addr);

        return buf.data();
    }

    /// @notice encoded null value as cbor
    /// @return cbor encoded null
    function serializeNull() internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeNull();

        return buf.data();
    }

    /// @notice deserialize cbor encoded filecoin address to bytes
    /// @param ret cbor encoded filecoin address
    /// @return raw bytes representing a filecoin address
    function deserializeAddress(bytes memory ret) internal pure returns (bytes memory) {
        bytes memory addr;
        uint byteIdx = 0;

        (addr, byteIdx) = ret.readBytes(byteIdx);

        return addr;
    }

    /// @notice deserialize cbor encoded string
    /// @param ret cbor encoded string (in bytes)
    /// @return decoded string
    function deserializeString(bytes memory ret) internal pure returns (string memory) {
        string memory response;
        uint byteIdx = 0;

        (response, byteIdx) = ret.readString(byteIdx);

        return response;
    }

    /// @notice deserialize cbor encoded bool
    /// @param ret cbor encoded bool (in bytes)
    /// @return decoded bool
    function deserializeBool(bytes memory ret) internal pure returns (bool) {
        bool response;
        uint byteIdx = 0;

        (response, byteIdx) = ret.readBool(byteIdx);

        return response;
    }

    /// @notice deserialize cbor encoded BigInt
    /// @param ret cbor encoded BigInt (in bytes)
    /// @return decoded BigInt
    /// @dev BigInts are cbor encoded as bytes string first. That is why it unwraps the cbor encoded bytes first, and then parse the result into BigInt
    function deserializeBytesBigInt(bytes memory ret) internal pure returns (CommonTypes.BigInt memory) {
        bytes memory tmp;
        uint byteIdx = 0;

        if (ret.length > 0) {
            (tmp, byteIdx) = ret.readBytes(byteIdx);
            if (tmp.length > 0) {
                return tmp.deserializeBigInt();
            }
        }

        return CommonTypes.BigInt(new bytes(0), false);
    }

    /// @notice deserialize cbor encoded uint64
    /// @param rawResp cbor encoded uint64 (in bytes)
    /// @return decoded uint64
    function deserializeUint64(bytes memory rawResp) internal pure returns (uint64) {
        uint byteIdx = 0;
        uint64 value;

        (value, byteIdx) = rawResp.readUInt64(byteIdx);
        return value;
    }

    /// @notice deserialize cbor encoded int64
    /// @param rawResp cbor encoded int64 (in bytes)
    /// @return decoded int64
    function deserializeInt64(bytes memory rawResp) internal pure returns (int64) {
        uint byteIdx = 0;
        int64 value;

        (value, byteIdx) = rawResp.readInt64(byteIdx);
        return value;
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/cbor/FilecoinCbor.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;





/// @title This library is a set of functions meant to handle CBOR serialization and deserialization for general data types on the filecoin network.
/// @author Zondax AG
library FilecoinCBOR {
    using Buffer for Buffer.buffer;
    using CBOR for CBOR.CBORBuffer;
    using CBORDecoder for *;
    using BigIntCBOR for *;

    uint8 private constant MAJOR_TYPE_TAG = 6;
    uint8 private constant TAG_TYPE_CID_CODE = 42;
    uint8 private constant PAYLOAD_LEN_8_BITS = 24;

    /// @notice write CID into a cbor buffer
    /// @dev the cbor major will be 6 (type tag) and the tag type is 42, as per filecoin definition
    /// @param buf buffer containing the actual cbor serialization process
    /// @param value cid data to serialize as cbor
    function writeCid(CBOR.CBORBuffer memory buf, bytes memory value) internal pure {
        buf.buf.appendUint8(uint8(((MAJOR_TYPE_TAG << 5) | PAYLOAD_LEN_8_BITS)));
        buf.buf.appendUint8(TAG_TYPE_CID_CODE);
        buf.writeBytes(value);
    }

    /// @notice serialize filecoin address to cbor encoded
    /// @param addr filecoin address to serialize
    /// @return cbor serialized data as bytes
    function serializeAddress(CommonTypes.FilAddress memory addr) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.writeBytes(addr.data);

        return buf.data();
    }

    /// @notice serialize a BigInt value wrapped in a cbor fixed array.
    /// @param value BigInt to serialize as cbor inside an
    /// @return cbor serialized data as bytes
    function serializeArrayBigInt(CommonTypes.BigInt memory value) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(1);
        buf.writeBytes(value.serializeBigInt());

        return buf.data();
    }

    /// @notice serialize a FilAddress value wrapped in a cbor fixed array.
    /// @param addr FilAddress to serialize as cbor inside an
    /// @return cbor serialized data as bytes
    function serializeArrayFilAddress(CommonTypes.FilAddress memory addr) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(1);
        buf.writeBytes(addr.data);

        return buf.data();
    }

    /// @notice deserialize a FilAddress wrapped on a cbor fixed array coming from a actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of FilAddress created based on parsed data
    function deserializeArrayFilAddress(bytes memory rawResp) internal pure returns (CommonTypes.FilAddress memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        (ret.data, byteIdx) = rawResp.readBytes(byteIdx);

        return ret;
    }

    /// @notice deserialize a BigInt wrapped on a cbor fixed array coming from a actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of BigInt created based on parsed data
    function deserializeArrayBigInt(bytes memory rawResp) internal pure returns (CommonTypes.BigInt memory) {
        uint byteIdx = 0;
        uint len;
        bytes memory tmp;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 1);

        (tmp, byteIdx) = rawResp.readBytes(byteIdx);
        return tmp.deserializeBigInt();
    }

    /// @notice serialize UniversalReceiverParams struct to cbor in order to pass as arguments to an actor
    /// @param params UniversalReceiverParams to serialize as cbor
    /// @return cbor serialized data as bytes
    function serializeUniversalReceiverParams(CommonTypes.UniversalReceiverParams memory params) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(2);
        buf.writeUInt64(params.type_);
        buf.writeBytes(params.payload);

        return buf.data();
    }

    /// @notice deserialize UniversalReceiverParams cbor to struct when receiving a message
    /// @param rawResp cbor encoded response
    /// @return ret new instance of UniversalReceiverParams created based on parsed data
    function deserializeUniversalReceiverParams(bytes memory rawResp) internal pure returns (CommonTypes.UniversalReceiverParams memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        require(len == 2, "Wrong numbers of parameters (should find 2)");

        (ret.type_, byteIdx) = rawResp.readUInt32(byteIdx);
        (ret.payload, byteIdx) = rawResp.readBytes(byteIdx);
    }

    /// @notice attempt to read a FilActorId value
    /// @param rawResp cbor encoded bytes to parse from
    /// @param byteIdx current position to read on the cbor encoded bytes
    /// @return a FilActorId decoded from input bytes and the byte index after moving past the value
    function readFilActorId(bytes memory rawResp, uint byteIdx) internal pure returns (CommonTypes.FilActorId, uint) {
        uint64 tmp = 0;

        (tmp, byteIdx) = rawResp.readUInt64(byteIdx);
        return (CommonTypes.FilActorId.wrap(tmp), byteIdx);
    }

    /// @notice write FilActorId into a cbor buffer
    /// @dev FilActorId is just wrapping a uint64
    /// @param buf buffer containing the actual cbor serialization process
    /// @param id FilActorId to serialize as cbor
    function writeFilActorId(CBOR.CBORBuffer memory buf, CommonTypes.FilActorId id) internal pure {
        buf.writeUInt64(CommonTypes.FilActorId.unwrap(id));
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/types/MinerTypes.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;


/// @title Filecoin miner actor types for Solidity.
/// @author Zondax AG
library MinerTypes {
    uint constant GetOwnerMethodNum = 3275365574;
    uint constant ChangeOwnerAddressMethodNum = 1010589339;
    uint constant IsControllingAddressMethodNum = 348244887;
    uint constant GetSectorSizeMethodNum = 3858292296;
    uint constant GetAvailableBalanceMethodNum = 4026106874;
    uint constant GetVestingFundsMethodNum = 1726876304;
    uint constant ChangeBeneficiaryMethodNum = 1570634796;
    uint constant GetBeneficiaryMethodNum = 4158972569;
    uint constant ChangeWorkerAddressMethodNum = 3302309124;
    uint constant ChangePeerIDMethodNum = 1236548004;
    uint constant ChangeMultiaddrsMethodNum = 1063480576;
    uint constant RepayDebtMethodNum = 3665352697;
    uint constant ConfirmChangeWorkerAddressMethodNum = 2354970453;
    uint constant GetPeerIDMethodNum = 2812875329;
    uint constant GetMultiaddrsMethodNum = 1332909407;
    uint constant WithdrawBalanceMethodNum = 2280458852;

    /// @param owner owner address.
    /// @param proposed owner address.
    struct GetOwnerReturn {
        CommonTypes.FilAddress owner;
        CommonTypes.FilAddress proposed;
    }

    /// @param vesting_funds funds
    struct GetVestingFundsReturn {
        VestingFunds[] vesting_funds;
    }

    /// @param new_beneficiary the new beneficiary address.
    /// @param new_quota the new quota token amount.
    /// @param new_expiration the epoch that the new quota will be expired.
    struct ChangeBeneficiaryParams {
        CommonTypes.FilAddress new_beneficiary;
        CommonTypes.BigInt new_quota;
        uint64 new_expiration;
    }

    /// @param active current active beneficiary.
    /// @param proposed the proposed and pending beneficiary.
    struct GetBeneficiaryReturn {
        ActiveBeneficiary active;
        PendingBeneficiaryChange proposed;
    }

    /// @param new_worker the new worker address.
    /// @param new_control_addresses the new controller addresses.
    struct ChangeWorkerAddressParams {
        CommonTypes.FilAddress new_worker;
        CommonTypes.FilAddress[] new_control_addresses;
    }

    /// @param new_multi_addrs the new multi-signature address.
    struct ChangeMultiaddrsParams {
        CommonTypes.FilAddress[] new_multi_addrs;
    }

    /// @param multi_addrs the multi-signature address.
    struct GetMultiaddrsReturn {
        CommonTypes.FilAddress[] multi_addrs;
    }

    /// @param epoch the epoch of funds vested.
    /// @param amount the amount of funds vested.
    struct VestingFunds {
        int64 epoch;
        CommonTypes.BigInt amount;
    }

    /// @param quota the quota token amount.
    /// @param used_quota the used quota token amount.
    /// @param expiration the epoch that the quota will be expired.
    struct BeneficiaryTerm {
        CommonTypes.BigInt quota;
        CommonTypes.BigInt used_quota;
        uint64 expiration;
    }

    /// @param beneficiary the address of the beneficiary.
    /// @param term BeneficiaryTerm
    struct ActiveBeneficiary {
        CommonTypes.FilAddress beneficiary;
        BeneficiaryTerm term;
    }

    /// @param new_beneficiary the new beneficiary address.
    /// @param new_quota the new quota token amount.
    /// @param new_expiration the epoch that the new quota will be expired.
    /// @param approved_by_beneficiary if this proposal is approved by beneficiary or not.
    /// @param approved_by_nominee if this proposal is approved by nominee or not.
    struct PendingBeneficiaryChange {
        CommonTypes.FilAddress new_beneficiary;
        CommonTypes.BigInt new_quota;
        uint64 new_expiration;
        bool approved_by_beneficiary;
        bool approved_by_nominee;
    }

    enum SectorSize {
        _2KiB,
        _8MiB,
        _512MiB,
        _32GiB,
        _64GiB
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/utils/Misc.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;

/// @title Library containing miscellaneous functions used on the project
/// @author Zondax AG
library Misc {
    uint64 constant DAG_CBOR_CODEC = 0x71;
    uint64 constant CBOR_CODEC = 0x51;
    uint64 constant NONE_CODEC = 0x00;

    // Code taken from Openzeppelin repo
    // Link: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/0320a718e8e07b1d932f5acb8ad9cec9d9eed99b/contracts/utils/math/SignedMath.sol#L37-L42
    /// @notice get the abs from a signed number
    /// @param n number to get abs from
    /// @return unsigned number
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/cbor/MinerCbor.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;





/// @title This library is a set of functions meant to handle CBOR parameters serialization and return values deserialization for Miner actor exported methods.
/// @author Zondax AG
library MinerCBOR {
    using CBOR for CBOR.CBORBuffer;
    using CBORDecoder for bytes;
    using BigIntCBOR for CommonTypes.BigInt;
    using BigIntCBOR for bytes;

    /// @notice serialize ChangeBeneficiaryParams struct to cbor in order to pass as arguments to the miner actor
    /// @param params ChangeBeneficiaryParams to serialize as cbor
    /// @return cbor serialized data as bytes
    function serializeChangeBeneficiaryParams(MinerTypes.ChangeBeneficiaryParams memory params) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(3);
        buf.writeBytes(params.new_beneficiary.data);
        buf.writeBytes(params.new_quota.serializeBigInt());
        buf.writeUInt64(params.new_expiration);

        return buf.data();
    }

    /// @notice deserialize GetOwnerReturn struct from cbor encoded bytes coming from a miner actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetOwnerReturn created based on parsed data
    function deserializeGetOwnerReturn(bytes memory rawResp) internal pure returns (MinerTypes.GetOwnerReturn memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 2);

        (ret.owner.data, byteIdx) = rawResp.readBytes(byteIdx);

        if (!rawResp.isNullNext(byteIdx)) {
            (ret.proposed.data, byteIdx) = rawResp.readBytes(byteIdx);
        } else {
            ret.proposed.data = new bytes(0);
        }

        return ret;
    }

    /// @notice deserialize GetBeneficiaryReturn struct from cbor encoded bytes coming from a miner actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetBeneficiaryReturn created based on parsed data
    function deserializeGetBeneficiaryReturn(bytes memory rawResp) internal pure returns (MinerTypes.GetBeneficiaryReturn memory ret) {
        bytes memory tmp;
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 2);

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 2);

        (ret.active.beneficiary.data, byteIdx) = rawResp.readBytes(byteIdx);

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 3);

        (tmp, byteIdx) = rawResp.readBytes(byteIdx);
        if (tmp.length > 0) {
            ret.active.term.quota = tmp.deserializeBigInt();
        } else {
            ret.active.term.quota = CommonTypes.BigInt(new bytes(0), false);
        }

        (tmp, byteIdx) = rawResp.readBytes(byteIdx);
        if (tmp.length > 0) {
            ret.active.term.used_quota = tmp.deserializeBigInt();
        } else {
            ret.active.term.used_quota = CommonTypes.BigInt(new bytes(0), false);
        }

        (ret.active.term.expiration, byteIdx) = rawResp.readUInt64(byteIdx);

        if (!rawResp.isNullNext(byteIdx)) {
            (len, byteIdx) = rawResp.readFixedArray(byteIdx);
            assert(len == 5);

            (ret.proposed.new_beneficiary.data, byteIdx) = rawResp.readBytes(byteIdx);

            (tmp, byteIdx) = rawResp.readBytes(byteIdx);
            if (tmp.length > 0) {
                ret.proposed.new_quota = tmp.deserializeBigInt();
            } else {
                ret.proposed.new_quota = CommonTypes.BigInt(new bytes(0), false);
            }

            (ret.proposed.new_expiration, byteIdx) = rawResp.readUInt64(byteIdx);
            (ret.proposed.approved_by_beneficiary, byteIdx) = rawResp.readBool(byteIdx);
            (ret.proposed.approved_by_nominee, byteIdx) = rawResp.readBool(byteIdx);
        }

        return ret;
    }

    /// @notice deserialize GetVestingFundsReturn struct from cbor encoded bytes coming from a miner actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetVestingFundsReturn created based on parsed data
    function deserializeGetVestingFundsReturn(bytes memory rawResp) internal pure returns (MinerTypes.GetVestingFundsReturn memory ret) {
        int64 epoch;
        CommonTypes.BigInt memory amount;
        bytes memory tmp;

        uint byteIdx = 0;
        uint len;
        uint leni;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 1);

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        ret.vesting_funds = new MinerTypes.VestingFunds[](len);

        for (uint i = 0; i < len; i++) {
            (leni, byteIdx) = rawResp.readFixedArray(byteIdx);
            assert(leni == 2);
            
            (epoch, byteIdx) = rawResp.readInt64(byteIdx);
            (tmp, byteIdx) = rawResp.readBytes(byteIdx);

            amount = tmp.deserializeBigInt();
            ret.vesting_funds[i] = MinerTypes.VestingFunds(epoch, amount);
        }

        return ret;
    }

    /// @notice serialize ChangeWorkerAddressParams struct to cbor in order to pass as arguments to the miner actor
    /// @param params ChangeWorkerAddressParams to serialize as cbor
    /// @return cbor serialized data as bytes
    function serializeChangeWorkerAddressParams(MinerTypes.ChangeWorkerAddressParams memory params) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(2);
        buf.writeBytes(params.new_worker.data);
        buf.startFixedArray(uint64(params.new_control_addresses.length));

        for (uint64 i = 0; i < params.new_control_addresses.length; i++) {
            buf.writeBytes(params.new_control_addresses[i].data);
        }

        return buf.data();
    }

    /// @notice serialize ChangeMultiaddrsParams struct to cbor in order to pass as arguments to the miner actor
    /// @param params ChangeMultiaddrsParams to serialize as cbor
    /// @return cbor serialized data as bytes
    function serializeChangeMultiaddrsParams(MinerTypes.ChangeMultiaddrsParams memory params) internal pure returns (bytes memory) {
        CBOR.CBORBuffer memory buf = CBOR.create(64);

        buf.startFixedArray(1);
        buf.startFixedArray(uint64(params.new_multi_addrs.length));

        for (uint64 i = 0; i < params.new_multi_addrs.length; i++) {
            buf.writeBytes(params.new_multi_addrs[i].data);
        }

        return buf.data();
    }

    /// @notice deserialize GetMultiaddrsReturn struct from cbor encoded bytes coming from a miner actor call
    /// @param rawResp cbor encoded response
    /// @return ret new instance of GetMultiaddrsReturn created based on parsed data
    function deserializeGetMultiaddrsReturn(bytes memory rawResp) internal pure returns (MinerTypes.GetMultiaddrsReturn memory ret) {
        uint byteIdx = 0;
        uint len;

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        assert(len == 1);

        (len, byteIdx) = rawResp.readFixedArray(byteIdx);
        ret.multi_addrs = new CommonTypes.FilAddress[](len);

        for (uint i = 0; i < len; i++) {
            (ret.multi_addrs[i].data, byteIdx) = rawResp.readBytes(byteIdx);
        }

        return ret;
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/utils/Actor.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;


/// @title Call actors utilities library, meant to interact with Filecoin builtin actors
/// @author Zondax AG
library Actor {
    /// @notice precompile address for the call_actor precompile
    address constant CALL_ACTOR_ADDRESS = 0xfe00000000000000000000000000000000000003;

    /// @notice precompile address for the call_actor_id precompile
    address constant CALL_ACTOR_ID = 0xfe00000000000000000000000000000000000005;

    /// @notice flag used to indicate that the call_actor or call_actor_id should perform a static_call to the desired actor
    uint64 constant READ_ONLY_FLAG = 0x00000001;

    /// @notice flag used to indicate that the call_actor or call_actor_id should perform a delegate_call to the desired actor
    uint64 constant DEFAULT_FLAG = 0x00000000;

    /// @notice the provided address is not valid
    error InvalidAddress(bytes addr);

    /// @notice the smart contract has no enough balance to transfer
    error NotEnoughBalance(uint256 balance, uint256 value);

    /// @notice the provided actor id is not valid
    error InvalidActorID(CommonTypes.FilActorId actorId);

    /// @notice an error happened trying to call the actor
    error FailToCallActor();

    /// @notice the response received is not correct. In some case no response is expected and we received one, or a response was indeed expected and we received none.
    error InvalidResponseLength();

    /// @notice the codec received is not valid
    error InvalidCodec(uint64);

    /// @notice the called actor returned an error as part of its expected behaviour
    error ActorError(int256 errorCode);

    /// @notice allows to interact with an specific actor by its address (bytes format)
    /// @param actor_address actor address (bytes format) to interact with
    /// @param method_num id of the method from the actor to call
    /// @param codec how the request data passed as argument is encoded
    /// @param raw_request encoded arguments to be passed in the call
    /// @param value tokens to be transferred to the called actor
    /// @param static_call indicates if the call will be allowed to change the actor state or not (just read the state)
    /// @return payload (in bytes) with the actual response data (without codec or response code)
    function callByAddress(
        bytes memory actor_address,
        uint256 method_num,
        uint64 codec,
        bytes memory raw_request,
        uint256 value,
        bool static_call
    ) internal returns (bytes memory) {
        if (actor_address.length < 2) {
            revert InvalidAddress(actor_address);
        }

        uint balance = address(this).balance;
        if (balance < value) {
            revert NotEnoughBalance(balance, value);
        }

        // We have to delegate-call the call-actor precompile because the call-actor precompile will
        // call the target actor on our behalf. This will _not_ delegate to the target `actor_address`.
        //
        // Specifically:
        //
        // - `static_call == false`: `CALLER (you) --(DELEGATECALL)-> CALL_ACTOR_PRECOMPILE --(CALL)-> actor_address
        // - `static_call == true`:  `CALLER (you) --(DELEGATECALL)-> CALL_ACTOR_PRECOMPILE --(STATICCALL)-> actor_address
        (bool success, bytes memory data) = address(CALL_ACTOR_ADDRESS).delegatecall(
            abi.encode(uint64(method_num), value, static_call ? READ_ONLY_FLAG : DEFAULT_FLAG, codec, raw_request, actor_address)
        );
        if (!success) {
            revert FailToCallActor();
        }

        return readRespData(data);
    }

    /// @notice allows to interact with an specific actor by its id (uint64)
    /// @param target actor id (uint64) to interact with
    /// @param method_num id of the method from the actor to call
    /// @param codec how the request data passed as argument is encoded
    /// @param raw_request encoded arguments to be passed in the call
    /// @param value tokens to be transferred to the called actor
    /// @param static_call indicates if the call will be allowed to change the actor state or not (just read the state)
    /// @return payload (in bytes) with the actual response data (without codec or response code)
    function callByID(
        CommonTypes.FilActorId target,
        uint256 method_num,
        uint64 codec,
        bytes memory raw_request,
        uint256 value,
        bool static_call
    ) internal returns (bytes memory) {
        uint balance = address(this).balance;
        if (balance < value) {
            revert NotEnoughBalance(balance, value);
        }

        (bool success, bytes memory data) = address(CALL_ACTOR_ID).delegatecall(
            abi.encode(uint64(method_num), value, static_call ? READ_ONLY_FLAG : DEFAULT_FLAG, codec, raw_request, target)
        );
        if (!success) {
            revert FailToCallActor();
        }

        return readRespData(data);
    }

    /// @notice allows to interact with an non-singleton actors by its id (uint64)
    /// @param target actor id (uint64) to interact with
    /// @param method_num id of the method from the actor to call
    /// @param codec how the request data passed as argument is encoded
    /// @param raw_request encoded arguments to be passed in the call
    /// @param value tokens to be transfered to the called actor
    /// @param static_call indicates if the call will be allowed to change the actor state or not (just read the state)
    /// @dev it requires the id to be bigger than 99, as singleton actors are smaller than that
    function callNonSingletonByID(
        CommonTypes.FilActorId target,
        uint256 method_num,
        uint64 codec,
        bytes memory raw_request,
        uint256 value,
        bool static_call
    ) internal returns (bytes memory) {
        if (CommonTypes.FilActorId.unwrap(target) < 100) {
            revert InvalidActorID(target);
        }

        return callByID(target, method_num, codec, raw_request, value, static_call);
    }

    /// @notice parse the response an actor returned
    /// @notice it will validate the return code (success) and the codec (valid one)
    /// @param raw_response raw data (bytes) the actor returned
    /// @return the actual raw data (payload, in bytes) to be parsed according to the actor and method called
    function readRespData(bytes memory raw_response) internal pure returns (bytes memory) {
        (int256 exit, uint64 return_codec, bytes memory return_value) = abi.decode(raw_response, (int256, uint64, bytes));

        if (return_codec == Misc.NONE_CODEC) {
            if (return_value.length != 0) {
                revert InvalidResponseLength();
            }
        } else if (return_codec == Misc.CBOR_CODEC || return_codec == Misc.DAG_CBOR_CODEC) {
            if (return_value.length == 0) {
                revert InvalidResponseLength();
            }
        } else {
            revert InvalidCodec(return_codec);
        }

        if (exit != 0) {
            revert ActorError(exit);
        }

        return return_value;
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/MinerAPI.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;







/// @title This library is a proxy to a built-in Miner actor. Calling one of its methods will result in a cross-actor call being performed.
/// @notice During miner initialization, a miner actor is created on the chain, and this actor gives the miner its ID f0.... The miner actor is in charge of collecting all the payments sent to the miner.
/// @dev For more info about the miner actor, please refer to https://lotus.filecoin.io/storage-providers/operate/addresses/
/// @author Zondax AG
library MinerAPI {
    using MinerCBOR for *;
    using FilecoinCBOR for *;
    using BytesCBOR for bytes;

    /// @notice Income and returned collateral are paid to this address
    /// @notice This address is also allowed to change the worker address for the miner
    /// @param target The miner actor id you want to interact with
    /// @return the owner address of a Miner
    function getOwner(CommonTypes.FilActorId target) internal returns (MinerTypes.GetOwnerReturn memory) {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.GetOwnerMethodNum, Misc.NONE_CODEC, raw_request, 0, true);

        return result.deserializeGetOwnerReturn();
    }

    /// @param target  The miner actor id you want to interact with
    /// @param addr New owner address
    /// @notice Proposes or confirms a change of owner address.
    /// @notice If invoked by the current owner, proposes a new owner address for confirmation. If the proposed address is the current owner address, revokes any existing proposal that proposed address.
    function changeOwnerAddress(CommonTypes.FilActorId target, CommonTypes.FilAddress memory addr) internal {
        bytes memory raw_request = addr.serializeAddress();

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.ChangeOwnerAddressMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);
        if (result.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @param target  The miner actor id you want to interact with
    /// @param addr The "controlling" addresses are the Owner, the Worker, and all Control Addresses.
    /// @return Whether the provided address is "controlling".
    function isControllingAddress(CommonTypes.FilActorId target, CommonTypes.FilAddress memory addr) internal returns (bool) {
        bytes memory raw_request = addr.serializeAddress();

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.IsControllingAddressMethodNum, Misc.CBOR_CODEC, raw_request, 0, true);

        return result.deserializeBool();
    }

    /// @return the miner's sector size.
    /// @param target The miner actor id you want to interact with
    /// @dev For more information about sector sizes, please refer to https://spec.filecoin.io/systems/filecoin_mining/sector/#section-systems.filecoin_mining.sector
    function getSectorSize(CommonTypes.FilActorId target) internal returns (uint64) {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.GetSectorSizeMethodNum, Misc.NONE_CODEC, raw_request, 0, true);

        return result.deserializeUint64();
    }

    /// @param target The miner actor id you want to interact with
    /// @notice This is calculated as actor balance - (vesting funds + pre-commit deposit + initial pledge requirement + fee debt)
    /// @notice Can go negative if the miner is in IP debt.
    /// @return the available balance of this miner.
    function getAvailableBalance(CommonTypes.FilActorId target) internal returns (CommonTypes.BigInt memory) {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.GetAvailableBalanceMethodNum, Misc.NONE_CODEC, raw_request, 0, true);

        return result.deserializeBytesBigInt();
    }

    /// @param target The miner actor id you want to interact with
    /// @return the funds vesting in this miner as a list of (vesting_epoch, vesting_amount) tuples.
    function getVestingFunds(CommonTypes.FilActorId target) internal returns (MinerTypes.GetVestingFundsReturn memory) {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.GetVestingFundsMethodNum, Misc.NONE_CODEC, raw_request, 0, true);

        return result.deserializeGetVestingFundsReturn();
    }

    /// @param target The miner actor id you want to interact with
    /// @notice Proposes or confirms a change of beneficiary address.
    /// @notice A proposal must be submitted by the owner, and takes effect after approval of both the proposed beneficiary and current beneficiary, if applicable, any current beneficiary that has time and quota remaining.
    /// @notice See FIP-0029, https://github.com/filecoin-project/FIPs/blob/master/FIPS/fip-0029.md
    function changeBeneficiary(CommonTypes.FilActorId target, MinerTypes.ChangeBeneficiaryParams memory params) internal {
        bytes memory raw_request = params.serializeChangeBeneficiaryParams();

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.ChangeBeneficiaryMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);
        if (result.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @param target The miner actor id you want to interact with
    /// @notice This method is for use by other actors (such as those acting as beneficiaries), and to abstract the state representation for clients.
    /// @notice Retrieves the currently active and proposed beneficiary information.
    function getBeneficiary(CommonTypes.FilActorId target) internal returns (MinerTypes.GetBeneficiaryReturn memory) {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.GetBeneficiaryMethodNum, Misc.NONE_CODEC, raw_request, 0, true);

        return result.deserializeGetBeneficiaryReturn();
    }

    /// @param target The miner actor id you want to interact with
    function changeWorkerAddress(CommonTypes.FilActorId target, MinerTypes.ChangeWorkerAddressParams memory params) internal {
        bytes memory raw_request = params.serializeChangeWorkerAddressParams();

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.ChangeWorkerAddressMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);
        if (result.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @param target The miner actor id you want to interact with
    function changePeerId(CommonTypes.FilActorId target, CommonTypes.FilAddress memory newId) internal {
        bytes memory raw_request = newId.serializeArrayFilAddress();

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.ChangePeerIDMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);
        if (result.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @param target The miner actor id you want to interact with
    function changeMultiaddresses(CommonTypes.FilActorId target, MinerTypes.ChangeMultiaddrsParams memory params) internal {
        bytes memory raw_request = params.serializeChangeMultiaddrsParams();

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.ChangeMultiaddrsMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);
        if (result.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @param target The miner actor id you want to interact with
    function repayDebt(CommonTypes.FilActorId target) internal {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.RepayDebtMethodNum, Misc.NONE_CODEC, raw_request, 0, false);
        if (result.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @param target The miner actor id you want to interact with
    function confirmChangeWorkerAddress(CommonTypes.FilActorId target) internal {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.ConfirmChangeWorkerAddressMethodNum, Misc.NONE_CODEC, raw_request, 0, false);
        if (result.length != 0) {
            revert Actor.InvalidResponseLength();
        }
    }

    /// @param target The miner actor id you want to interact with
    function getPeerId(CommonTypes.FilActorId target) internal returns (CommonTypes.FilAddress memory) {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.GetPeerIDMethodNum, Misc.NONE_CODEC, raw_request, 0, true);

        return result.deserializeArrayFilAddress();
    }

    /// @param target The miner actor id you want to interact with
    function getMultiaddresses(CommonTypes.FilActorId target) internal returns (MinerTypes.GetMultiaddrsReturn memory) {
        bytes memory raw_request = new bytes(0);

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.GetMultiaddrsMethodNum, Misc.NONE_CODEC, raw_request, 0, true);

        return result.deserializeGetMultiaddrsReturn();
    }

    /// @param target The miner actor id you want to interact with
    /// @param amount the amount you want to withdraw
    function withdrawBalance(CommonTypes.FilActorId target, CommonTypes.BigInt memory amount) internal returns (CommonTypes.BigInt memory) {
        bytes memory raw_request = amount.serializeArrayBigInt();

        bytes memory result = Actor.callNonSingletonByID(target, MinerTypes.WithdrawBalanceMethodNum, Misc.CBOR_CODEC, raw_request, 0, false);

        return result.deserializeBytesBigInt();
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/PrecompilesAPI.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
//
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.0;

/// @title This library simplify the call of FEVM precompiles contracts.
/// @author Zondax AG
library PrecompilesAPI {
    address constant RESOLVE_ADDRESS_PRECOMPILE_ADDR = 0xFE00000000000000000000000000000000000001;
    address constant LOOKUP_DELEGATED_ADDRESS_PRECOMPILE_ADDR = 0xfE00000000000000000000000000000000000002;

    /// @notice get the actor id from an actor address
    /// @param addr actor address you want to get id from (in bytes format, not string)
    /// @return the actor id
    function resolveAddress(CommonTypes.FilAddress memory addr) internal view returns (uint64) {
        (bool success, bytes memory raw_response) = address(RESOLVE_ADDRESS_PRECOMPILE_ADDR).staticcall(addr.data);
        require(success == true, "resolve address error");

        uint256 actor_id = abi.decode(raw_response, (uint256));

        return uint64(actor_id);
    }

    /// @notice get the actor id from an eth address
    /// @param addr eth address you want to get id from (in bytes format)
    /// @return the actor id
    function resolveEthAddress(address addr) internal view returns (uint64) {
        bytes memory delegatedAddr = abi.encodePacked(hex"040a", addr);

        (bool success, bytes memory raw_response) = address(RESOLVE_ADDRESS_PRECOMPILE_ADDR).staticcall(delegatedAddr);
        require(success == true, "resolve eth address error");

        uint256 actor_id = abi.decode(raw_response, (uint256));

        return uint64(actor_id);
    }

    /// @notice get the actor delegated address (f4) from an actor id
    /// @param actor_id actor id you want to get the delegated address (f4) from
    /// @return delegated address in bytes format (not string)
    function lookupDelegatedAddress(uint64 actor_id) internal view returns (bytes memory) {
        (bool success, bytes memory raw_response) = address(LOOKUP_DELEGATED_ADDRESS_PRECOMPILE_ADDR).staticcall(abi.encodePacked(uint256(actor_id)));
        require(success == true, "lookup delegated address error");

        return raw_response;
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/utils/Leb128.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2023 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;

/// @notice This library implement the leb128
/// @author Zondax AG
library Leb128 {
    using Buffer for Buffer.buffer;

    /// @notice encode a unsigned integer 64bits into bytes
    /// @param value the actor ID to encode
    /// @return result return the value in bytes
    function encodeUnsignedLeb128FromUInt64(uint64 value) internal pure returns (Buffer.buffer memory result) {
        while (true) {
            uint64 byte_ = value & 0x7f;
            value >>= 7;
            if (value == 0) {
                result.appendUint8(uint8(byte_));
                return result;
            }
            result.appendUint8(uint8(byte_ | 0x80));
        }
    }
}


// File @zondax/filecoin-solidity/contracts/v0.8/utils/FilAddresses.sol@v3.0.0-beta.1

/*******************************************************************************
 *   (c) 2022 Zondax AG
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 ********************************************************************************/
// DRAFT!! THIS CODE HAS NOT BEEN AUDITED - USE ONLY FOR PROTOTYPING


pragma solidity ^0.8.17;



/// @notice This library is a set a functions that allows to handle filecoin addresses conversions and validations
/// @author Zondax AG
library FilAddresses {
    using Buffer for Buffer.buffer;

    error InvalidAddress();

    /// @notice allow to get a FilAddress from an eth address
    /// @param addr eth address to convert
    /// @return new filecoin address
    function fromEthAddress(address addr) internal pure returns (CommonTypes.FilAddress memory) {
        return CommonTypes.FilAddress(abi.encodePacked(hex"0410", addr));
    }

    /// @notice allow to create a Filecoin address from an actorID
    /// @param actorID uint64 actorID
    /// @return address filecoin address
    function fromActorID(uint64 actorID) internal pure returns (CommonTypes.FilAddress memory) {
        Buffer.buffer memory result = Leb128.encodeUnsignedLeb128FromUInt64(actorID);
        return CommonTypes.FilAddress(abi.encodePacked(hex"00", result.buf));
    }

    /// @notice allow to create a Filecoin address from bytes
    /// @param data address in bytes format
    /// @return filecoin address
    function fromBytes(bytes memory data) internal pure returns (CommonTypes.FilAddress memory) {
        CommonTypes.FilAddress memory newAddr = CommonTypes.FilAddress(data);
        if (!validate(newAddr)) {
            revert InvalidAddress();
        }

        return newAddr;
    }

    /// @notice allow to validate if an address is valid or not
    /// @dev we are only validating known address types. If the type is not known, the default value is true
    /// @param addr the filecoin address to validate
    /// @return whether the address is valid or not
    function validate(CommonTypes.FilAddress memory addr) internal pure returns (bool) {
        if (addr.data[0] == 0x00) {
            return addr.data.length <= 10;
        } else if (addr.data[0] == 0x01 || addr.data[0] == 0x02) {
            return addr.data.length == 21;
        } else if (addr.data[0] == 0x03) {
            return addr.data.length == 49;
        } else if (addr.data[0] == 0x04) {
            return addr.data.length <= 64;
        }

        return addr.data.length <= 256;
    }
}


// File contracts/ErrorReporter.sol


pragma solidity ^0.8.10;

contract ComptrollerErrorReporter {
    error IllegalArgument();
    error PriceError();
    error Unauthorized();
    error MarketNotListed();
    error ExitMarketBalanceOwned();
    error MintPaused();
    error RedeemTokensZero();
    error BorrowPaused();
    error SenderNotCToken();
    error BorrowCapReached();
    error RepayTooMuch();
    error SeizePaused();
    error TransferPaused();
    error MarketAlreadyListed();
    error InvalidBlockNumber();
    error InvalidCollaternalFactor();
    error ExitMarketFailed(uint);
    enum Error {
        NO_ERROR,
        COMPTROLLER_MISMATCH,
        INSUFFICIENT_SHORTFALL,
        INSUFFICIENT_LIQUIDITY,
        MARKET_NOT_LISTED,
        PRICE_ERROR,
        TOO_MUCH_REPAY
    }
}

contract TokenErrorReporter {
    uint public constant NO_ERROR = 0; // support legacy return codes

    error TransferComptrollerRejection(uint256 errorCode);
    error TransferNotAllowed();
    error TransferNotEnough();
    error TransferTooMuch();

    error MintComptrollerRejection(uint256 errorCode);
    error MintFreshnessCheck();

    error RedeemComptrollerRejection(uint256 errorCode);
    error RedeemFreshnessCheck();
    error RedeemTransferOutNotPossible();

    error BorrowComptrollerRejection(uint256 errorCode);
    error BorrowFreshnessCheck();
    error BorrowCashNotAvailable();

    error RepayBorrowComptrollerRejection(uint256 errorCode);
    error RepayBorrowFreshnessCheck();

    error LiquidateComptrollerRejection(uint256 errorCode);
    error LiquidateFreshnessCheck();
    error LiquidateCollateralFreshnessCheck();
    error LiquidateAccrueBorrowInterestFailed(uint256 errorCode);
    error LiquidateAccrueCollateralInterestFailed(uint256 errorCode);
    error LiquidateLiquidatorIsBorrower();
    error LiquidateCloseAmountIsZero();
    error LiquidateCloseAmountIsUintMax();
    error LiquidateRepayBorrowFreshFailed(uint256 errorCode);

    error LiquidateSeizeComptrollerRejection(uint256 errorCode);
    error LiquidateSeizeLiquidatorIsBorrower();

    error AcceptAdminPendingAdminCheck();

    error SetComptrollerOwnerCheck();
    error SetPendingAdminOwnerCheck();

    error SetReserveFactorAdminCheck();
    error SetReserveFactorFreshCheck();
    error SetReserveFactorBoundsCheck();

    error AddReservesFactorFreshCheck(uint256 actualAddAmount);

    error ReduceReservesAdminCheck();
    error ReduceReservesFreshCheck();
    error ReduceReservesCashNotAvailable();
    error ReduceReservesCashValidation();

    error SetInterestRateModelOwnerCheck();
    error SetInterestRateModelFreshCheck();

    error InitialExchangeRateCannotBeZero();
    error MarketAlreadyInitialized();
    error Unauthorized();
    error BorrowRateTooHigh();
    error RedeemTokensInOrRedeemAmountInShouldBeZero();
    error LiquidateSizeTooMuch();
    error NotComptroller();
    error InvalidContractAddress();
}


// File contracts/FixedMath.sol


pragma solidity ^0.8.10;

/**
 * @title Exponential module for storing fixed-precision decimals
 * @author Compound
 * @notice Exp is a struct which stores decimals with a fixed precision of 18 decimal places.
 *         Thus, if we wanted to store the 5.1, mantissa would store 5.1e18. That is:
 *         `Exp({mantissa: 5100000000000000000})`.
 */
library FixedMath {
    error InvalidNumber(uint);
    uint constant expScale = 1e18;
    uint constant doubleScale = 1e36;
    uint constant halfExpScale = expScale/2;
    uint constant mantissaOne = expScale;

    type Exp is uint;
 
    type Double is uint;

    /**
     * @dev Truncates the given exp to a whole number value.
     *      For example, truncate(Exp{mantissa: 15 * expScale}) = 15
     */
    function truncate(Exp exp) pure internal returns (uint) {
        // Note: We are not using careful math here as we're performing a division that cannot fail
        return Exp.unwrap(exp) / expScale;
    }

    /**
     * @dev Multiply an Exp by a scalar, then truncate to return an unsigned integer.
     */
    function mul_ScalarTruncate(Exp a, uint scalar) pure internal returns (uint) {
        Exp product = mul_(a, scalar);
        return truncate(product);
    }

    /**
     * @dev Multiply an Exp by a scalar, truncate, then add an to an unsigned integer, returning an unsigned integer.
     */
    function mul_ScalarTruncateAddUInt(Exp a, uint scalar, uint addend) pure internal returns (uint) {
        Exp product = mul_(a, scalar);
        return add_(truncate(product), addend);
    }

    /**
     * @dev Checks if first Exp is less than second Exp.
     */
    function lessThanExp(Exp left, Exp right) pure internal returns (bool) {
        return Exp.unwrap(left) < Exp.unwrap(right);
    }

    /**
     * @dev Checks if left Exp <= right Exp.
     */
    function lessThanOrEqualExp(Exp left, Exp right) pure internal returns (bool) {
        return Exp.unwrap(left) <= Exp.unwrap(right);
    }

    /**
     * @dev Checks if left Exp > right Exp.
     */
    function greaterThanExp(Exp left, Exp right) pure internal returns (bool) {
        return Exp.unwrap(left) > Exp.unwrap(right);
    }

    /**
     * @dev returns true if Exp is exactly zero
     */
    function isZeroExp(Exp value) pure internal returns (bool) {
        return Exp.unwrap(value) == 0;
    }

    function safe224(uint n) pure internal returns (uint224) {
        if (n >= 2**224) revert InvalidNumber(n);
        return uint224(n);
    }

    function safe32(uint n) pure internal returns (uint32) {
        if (n >= 2**32) revert InvalidNumber(n);
        return uint32(n);
    }

    function add_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(add_(Exp.unwrap(a), Exp.unwrap(b)));
    }

    function add_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(add_(Double.unwrap(a), Double.unwrap(b)));
    }

    function add_(uint a, uint b) pure internal returns (uint) {
        return a + b;
    }

    function sub_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(sub_(Exp.unwrap(a), Exp.unwrap(b)));
    }

    function sub_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(sub_(Double.unwrap(a), Double.unwrap(b)));
    }

    function sub_(uint a, uint b) pure internal returns (uint) {
        return a - b;
    }

    function mul_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(mul_(Exp.unwrap(a), Exp.unwrap(b)) / expScale);
    }

    function mul_(Exp a, uint b) pure internal returns (Exp) {
        return Exp.wrap(mul_(Exp.unwrap(a), b));
    }

    function mul_(uint a, Exp b) pure internal returns (uint) {
        return mul_(a, Exp.unwrap(b)) / expScale;
    }

    function mul_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(mul_(Double.unwrap(a), Double.unwrap(b)) / doubleScale);
    }

    function mul_(Double a, uint b) pure internal returns (Double) {
        return Double.wrap(mul_(Double.unwrap(a), b));
    }

    function mul_(uint a, Double b) pure internal returns (uint) {
        return mul_(a, Double.unwrap(b)) / doubleScale;
    }

    function mul_(uint a, uint b) pure internal returns (uint) {
        return a * b;
    }

    function div_(Exp a, Exp b) pure internal returns (Exp) {
        return Exp.wrap(div_(mul_(Exp.unwrap(a), expScale), Exp.unwrap(b)));
    }

    function div_(Exp a, uint b) pure internal returns (Exp) {
        return Exp.wrap(div_(Exp.unwrap(a), b));
    }

    function div_(uint a, Exp b) pure internal returns (uint) {
        return div_(mul_(a, expScale), Exp.unwrap(b));
    }

    function div_(Double a, Double b) pure internal returns (Double) {
        return Double.wrap(div_(mul_(Double.unwrap(a), doubleScale), Double.unwrap(b)));
    }

    function div_(Double a, uint b) pure internal returns (Double) {
        return Double.wrap(div_(Double.unwrap(a), b));
    }

    function div_(uint a, Double b) pure internal returns (uint) {
        return div_(mul_(a, doubleScale), Double.unwrap(b));
    }

    function div_(uint a, uint b) pure internal returns (uint) {
        return a / b;
    }

    function fraction(uint a, uint b) pure internal returns (Double) {
        return Double.wrap(div_(mul_(a, doubleScale), b));
    }
}


// File contracts/Interfaces/ISmartAccountFactory.sol


pragma solidity ^0.8.10;

interface ISmartAccountFactory {
    function isValidSmartAccount(address account) external view returns (bool);
}


// File contracts/Interfaces/ComptrollerInterface.sol


pragma solidity ^0.8.10;

abstract contract ComptrollerInterface {
    /// @notice Indicator that this is a Comptroller contract (for inspection)
    bool public constant isComptroller = true;

    /*** Assets You Are In ***/

    function enterMarkets(address[] calldata cTokens) virtual external;
    function exitMarket(address cToken) virtual external;

    /*** Policy Hooks ***/

    function mintAllowed(address cToken, address minter, uint mintAmount) virtual external returns (uint);

    function redeemAllowed(address cToken, address redeemer, uint redeemTokens) virtual external returns (uint);
    function redeemVerify(address cToken, address redeemer, uint redeemAmount, uint redeemTokens) virtual external;

    function borrowAllowed(address cToken, address borrower, uint borrowAmount) virtual external returns (uint);

    function repayBorrowAllowed(
        address cToken,
        address payer,
        address borrower,
        uint repayAmount) virtual external returns (uint);

    function liquidateBorrowAllowed(
        address cTokenBorrowed,
        address cTokenCollateral,
        address liquidator,
        address borrower,
        uint repayAmount) virtual external returns (uint);

    function seizeAllowed(
        address cTokenCollateral,
        address cTokenBorrowed,
        address liquidator,
        address borrower,
        uint seizeTokens) virtual external returns (uint);

    function transferAllowed(address cToken, address src, address dst, uint transferTokens) virtual external returns (uint);

    /*** Liquidity/Liquidation Calculations ***/

    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint repayAmount) virtual external view returns (uint, uint);
    
    function isValidSmartAccount(address account) virtual external returns (bool);
}


// File contracts/Interfaces/EIP20NonStandardInterface.sol


pragma solidity ^0.8.10;

/**
 * @title EIP20NonStandardInterface
 * @dev Version of ERC20 with no return values for `transfer` and `transferFrom`
 *  See https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
 */
interface EIP20NonStandardInterface {

    /**
     * @notice Get the total number of tokens in circulation
     * @return The supply of tokens
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return balance The balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transfer` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
      * @notice Transfer `amount` tokens from `msg.sender` to `dst`
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      */
    function transfer(address dst, uint256 amount) external;

    ///
    /// !!!!!!!!!!!!!!
    /// !!! NOTICE !!! `transferFrom` does not return a value, in violation of the ERC-20 specification
    /// !!!!!!!!!!!!!!
    ///

    /**
      * @notice Transfer `amount` tokens from `src` to `dst`
      * @param src The address of the source account
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      */
    function transferFrom(address src, address dst, uint256 amount) external;

    /**
      * @notice Approve `spender` to transfer up to `amount` from `src`
      * @dev This will overwrite the approval amount for `spender`
      *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
      * @param spender The address of the account which may transfer tokens
      * @param amount The number of tokens that are approved
      * @return success Whether or not the approval succeeded
      */
    function approve(address spender, uint256 amount) external returns (bool success);

    /**
      * @notice Get the current allowance from `owner` for `spender`
      * @param owner The address of the account which owns the tokens to be spent
      * @param spender The address of the account which may transfer tokens
      * @return remaining The number of tokens allowed to be spent
      */
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}


// File contracts/Interfaces/InterestRateModel.sol


pragma solidity ^0.8.10;

/**
  * @title Compound's InterestRateModel Interface
  * @author Compound
  */
abstract contract InterestRateModel {
    /// @notice Indicator that this is an InterestRateModel contract (for inspection)
    bool public constant isInterestRateModel = true;

    /**
      * @notice Calculates the current borrow interest rate per block
      * @param cash The total amount of cash the market has
      * @param borrows The total amount of borrows the market has outstanding
      * @param reserves The total amount of reserves the market has
      * @return The borrow rate per block (as a percentage, and scaled by 1e18)
      */
    function getBorrowRate(uint cash, uint borrows, uint reserves) virtual external view returns (uint);

    /**
      * @notice Calculates the current supply interest rate per block
      * @param cash The total amount of cash the market has
      * @param borrows The total amount of borrows the market has outstanding
      * @param reserves The total amount of reserves the market has
      * @param reserveFactorMantissa The current reserve factor the market has
      * @return The supply rate per block (as a percentage, and scaled by 1e18)
      */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) virtual external view returns (uint);
}


// File contracts/Interfaces/CTokenInterfaces.sol


pragma solidity ^0.8.10;




contract CTokenStorage {
    /**
     * @dev Guard variable for re-entrancy checks
     */
    bool internal _notEntered;

    /**
     * @notice EIP-20 token name for this token
     */
    string public name;

    /**
     * @notice EIP-20 token symbol for this token
     */
    string public symbol;

    /**
     * @notice EIP-20 token decimals for this token
     */
    uint8 public decimals;

    // Maximum borrow rate that can ever be applied (.0005% / block)
    uint internal constant borrowRateMaxMantissa = 0.0005e16;

    // Maximum fraction of interest that can be set aside for reserves
    uint internal constant reserveFactorMaxMantissa = 1e18;

    /**
     * @notice Administrator for this contract
     */
    address payable public admin;

    /**
     * @notice Pending administrator for this contract
     */
    address payable public pendingAdmin;

    /**
     * @notice Contract which oversees inter-cToken operations
     */
    ComptrollerInterface public comptroller;

    /**
     * @notice Model which tells what the current interest rate should be
     */
    InterestRateModel public interestRateModel;

    // Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
    uint internal initialExchangeRateMantissa;

    /**
     * @notice Fraction of interest currently set aside for reserves
     */
    uint public reserveFactorMantissa;

    /**
     * @notice Block number that interest was last accrued at
     */
    uint public accrualBlockNumber;

    /**
     * @notice Accumulator of the total earned interest rate since the opening of the market
     */
    uint public borrowIndex;

    /**
     * @notice Total amount of outstanding borrows of the underlying in this market
     */
    uint public totalBorrows;

    /**
     * @notice Total amount of reserves of the underlying held in this market
     */
    uint public totalReserves;

    /**
     * @notice Total number of tokens in circulation
     */
    uint public totalSupply;

    // Official record of token balances for each account
    mapping (address => uint) internal accountTokens;

    // Approved token transfer amounts on behalf of others
    mapping (address => mapping (address => uint)) internal transferAllowances;

    /**
     * @notice Container for borrow balance information
     * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
     * @member interestIndex Global borrowIndex as of the most recent balance-changing action
     */
    struct BorrowSnapshot {
        uint principal;
        uint interestIndex;
    }

    // Mapping of account addresses to outstanding borrow balances
    mapping(address => BorrowSnapshot) internal accountBorrows;

    /**
     * @notice Share of seized collateral that is added to reserves
     */
    uint public constant protocolSeizeShareMantissa = 2.8e16; //2.8%
}

abstract contract CTokenInterface is CTokenStorage {
    /**
     * @notice Indicator that this is a CToken contract (for inspection)
     */
    bool public constant isCToken = true;


    /*** Market Events ***/

    /**
     * @notice Event emitted when interest is accrued
     */
    event AccrueInterest(uint cashPrior, uint interestAccumulated, uint borrowIndex, uint totalBorrows);

    /**
     * @notice Event emitted when tokens are minted
     */
    event Mint(address minter, uint mintAmount, uint mintTokens);

    /**
     * @notice Event emitted when tokens are redeemed
     */
    event Redeem(address redeemer, uint redeemAmount, uint redeemTokens);

    /**
     * @notice Event emitted when underlying is borrowed
     */
    event Borrow(address borrower, uint borrowAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is repaid
     */
    event RepayBorrow(address payer, address borrower, uint repayAmount, uint accountBorrows, uint totalBorrows);

    /**
     * @notice Event emitted when a borrow is liquidated
     */
    event LiquidateBorrow(address liquidator, address borrower, uint repayAmount, address cTokenCollateral, uint seizeTokens);


    /*** Admin Events ***/

    /**
     * @notice Event emitted when pendingAdmin is changed
     */
    event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

    /**
     * @notice Event emitted when pendingAdmin is accepted, which means admin is updated
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @notice Event emitted when comptroller is changed
     */
    event NewComptroller(ComptrollerInterface oldComptroller, ComptrollerInterface newComptroller);

    /**
     * @notice Event emitted when interestRateModel is changed
     */
    event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

    /**
     * @notice Event emitted when the reserve factor is changed
     */
    event NewReserveFactor(uint oldReserveFactorMantissa, uint newReserveFactorMantissa);

    /**
     * @notice Event emitted when the reserves are added
     */
    event ReservesAdded(address benefactor, uint addAmount, uint newTotalReserves);

    /**
     * @notice Event emitted when the reserves are reduced
     */
    event ReservesReduced(address admin, uint reduceAmount, uint newTotalReserves);

    /**
     * @notice EIP20 Transfer event
     */
    event Transfer(address indexed from, address indexed to, uint amount);

    /**
     * @notice EIP20 Approval event
     */
    event Approval(address indexed owner, address indexed spender, uint amount);


    /*** User Interface ***/

    function transfer(address dst, uint amount) virtual external returns (bool);
    function transferFrom(address src, address dst, uint amount) virtual external returns (bool);
    function approve(address spender, uint amount) virtual external returns (bool);
    function allowance(address owner, address spender) virtual external view returns (uint);
    function balanceOf(address owner) virtual external view returns (uint);
    function balanceOfUnderlying(address owner) virtual external returns (uint);
    function getAccountSnapshot(address account) virtual external view returns (uint, uint, uint, uint);
    function borrowRatePerBlock() virtual external view returns (uint);
    function supplyRatePerBlock() virtual external view returns (uint);
    function totalBorrowsCurrent() virtual external returns (uint);
    function borrowBalanceCurrent(address account) virtual external returns (uint);
    function borrowBalanceStored(address account) virtual external view returns (uint);
    function exchangeRateCurrent() virtual external returns (uint);
    function exchangeRateStored() virtual external view returns (uint);
    function getCash() virtual external view returns (uint);
    function accrueInterest() virtual external returns (uint);
    function seize(address liquidator, address borrower, uint seizeTokens) virtual external returns (uint);


    /*** Admin Functions ***/

    function _setPendingAdmin(address payable newPendingAdmin) virtual external returns (uint);
    function _acceptAdmin() virtual external returns (uint);
    function _setComptroller(ComptrollerInterface newComptroller) virtual external returns (uint);
    function _setReserveFactor(uint newReserveFactorMantissa) virtual external returns (uint);
    function _reduceReserves(uint reduceAmount) virtual external returns (uint);
    function _setInterestRateModel(InterestRateModel newInterestRateModel) virtual external returns (uint);
}

contract CErc20Storage {
    /**
     * @notice Underlying asset for this CToken
     */
    address public underlying;
}

abstract contract CErc20Interface is CErc20Storage {

    /*** User Interface ***/

    function mint(uint mintAmount) virtual external returns (uint);
    function redeem(uint redeemTokens) virtual external returns (uint);
    function redeemUnderlying(uint redeemAmount) virtual external returns (uint);
    function borrow(uint borrowAmount) virtual external returns (uint);
    function repayBorrow(uint repayAmount) virtual external returns (uint);
    function repayBorrowBehalf(address borrower, uint repayAmount) virtual external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) virtual external returns (uint);
    function sweepToken(EIP20NonStandardInterface token) virtual external;


    /*** Admin Functions ***/
}

contract CDelegationStorage {
    /**
     * @notice Implementation address for this contract
     */
    address public implementation;
}

abstract contract CDelegatorInterface is CDelegationStorage {
    /**
     * @notice Emitted when implementation is changed
     */
    event NewImplementation(address oldImplementation, address newImplementation);

    /**
     * @notice Called by the admin to update the implementation of the delegator
     * @param implementation_ The address of the new implementation for delegation
     * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
     * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
     */
    function _setImplementation(address implementation_, bool allowResign, bytes memory becomeImplementationData) virtual external;
}

abstract contract CDelegateInterface is CDelegationStorage {
    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @dev Should revert if any issues arise which make it unfit for delegation
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes memory data) virtual external;

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() virtual external;
}


// File contracts/Interfaces/EIP20Interface.sol


pragma solidity ^0.8.10;

/**
 * @title ERC 20 Token Standard Interface
 *  https://eips.ethereum.org/EIPS/eip-20
 */
interface EIP20Interface {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    /**
      * @notice Get the total number of tokens in circulation
      * @return The supply of tokens
      */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Gets the balance of the specified address
     * @param owner The address from which the balance will be retrieved
     * @return balance The balance
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
      * @notice Transfer `amount` tokens from `msg.sender` to `dst`
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      * @return success Whether or not the transfer succeeded
      */
    function transfer(address dst, uint256 amount) external returns (bool success);

    /**
      * @notice Transfer `amount` tokens from `src` to `dst`
      * @param src The address of the source account
      * @param dst The address of the destination account
      * @param amount The number of tokens to transfer
      * @return success Whether or not the transfer succeeded
      */
    function transferFrom(address src, address dst, uint256 amount) external returns (bool success);

    /**
      * @notice Approve `spender` to transfer up to `amount` from `src`
      * @dev This will overwrite the approval amount for `spender`
      *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
      * @param spender The address of the account which may transfer tokens
      * @param amount The number of tokens that are approved (-1 means infinite)
      * @return success Whether or not the approval succeeded
      */
    function approve(address spender, uint256 amount) external returns (bool success);

    /**
      * @notice Get the current allowance from `owner` for `spender`
      * @param owner The address of the account which owns the tokens to be spent
      * @param spender The address of the account which may transfer tokens
      * @return remaining The number of tokens allowed to be spent (-1 means infinite)
      */
    function allowance(address owner, address spender) external view returns (uint256 remaining);

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}


// File contracts/Interfaces/ISmartAccount.sol


pragma solidity ^0.8.10;

interface ISmartAccount {
    function getNonStandardCollateralAssetValue() external view returns (uint);
    function withdraw(address token, uint amount, address to) external;
    function liquidate(address borrower, address liquidator) external;
}


// File contracts/CToken.sol


pragma solidity ^0.8.10;








/**
 * @title Compound's CToken Contract
 * @notice Abstract base for CTokens
 * @author Compound
 */
abstract contract CToken is CTokenInterface, TokenErrorReporter {
    /**
     * @notice Initialize the money market
     * @param comptroller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ EIP-20 name of this token
     * @param symbol_ EIP-20 symbol of this token
     * @param decimals_ EIP-20 decimal precision of this token
     */
    function initialize(ComptrollerInterface comptroller_,
                        InterestRateModel interestRateModel_,
                        uint initialExchangeRateMantissa_,
                        string memory name_,
                        string memory symbol_,
                        uint8 decimals_) public {
        if (msg.sender != admin) revert Unauthorized();
        if (accrualBlockNumber != 0 || borrowIndex != 0) revert MarketAlreadyInitialized();

        // Set initial exchange rate
        initialExchangeRateMantissa = initialExchangeRateMantissa_;
        if (initialExchangeRateMantissa == 0) revert InitialExchangeRateCannotBeZero();

        // Set the comptroller
        _setComptroller(comptroller_);

        // Initialize block number and borrow index (block number mocks depend on comptroller being set)
        accrualBlockNumber = getBlockNumber();
        borrowIndex = FixedMath.mantissaOne;

        // Set the interest rate model (depends on block number / borrow index)
        _setInterestRateModelFresh(interestRateModel_);

        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        // The counter starts true to prevent changing it from zero to non-zero (i.e. smaller cost/refund)
        _notEntered = true;
    }

    /**
     * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
     * @dev Called by both `transfer` and `transferFrom` internally
     * @param spender The address of the account performing the transfer
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param tokens The number of tokens to transfer
     * @return 0 if the transfer succeeded, else revert
     */
    function transferTokens(address spender, address src, address dst, uint tokens) internal returns (uint) {
        /* Fail if transfer not allowed */
        uint allowed = comptroller.transferAllowed(address(this), src, dst, tokens);
        if (allowed != 0) {
            revert TransferComptrollerRejection(allowed);
        }

        /* Do not allow self-transfers */
        if (src == dst) {
            revert TransferNotAllowed();
        }

        /* Get the allowance, infinite for the account owner */
        uint startingAllowance = 0;
        if (spender == src) {
            startingAllowance = type(uint).max;
        } else {
            startingAllowance = transferAllowances[src][spender];
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        accountTokens[src] = accountTokens[src] - tokens;
        accountTokens[dst] = accountTokens[dst] + tokens;

        /* Eat some of the allowance (if necessary) */
        if (startingAllowance != type(uint).max) {
            transferAllowances[src][spender] = startingAllowance - tokens;
        }

        /* We emit a Transfer event */
        emit Transfer(src, dst, tokens);

        return NO_ERROR;
    }

    /**
     * @notice Transfer `amount` tokens from `msg.sender` to `dst`
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transfer(address dst, uint256 amount) override external nonReentrant returns (bool) {
        return transferTokens(msg.sender, msg.sender, dst, amount) == NO_ERROR;
    }

    /**
     * @notice Transfer `amount` tokens from `src` to `dst`
     * @param src The address of the source account
     * @param dst The address of the destination account
     * @param amount The number of tokens to transfer
     * @return Whether or not the transfer succeeded
     */
    function transferFrom(address src, address dst, uint256 amount) override external nonReentrant returns (bool) {
        return transferTokens(msg.sender, src, dst, amount) == NO_ERROR;
    }

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (uint256.max means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) override external returns (bool) {
        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent (-1 means infinite)
     */
    function allowance(address owner, address spender) override external view returns (uint256) {
        return transferAllowances[owner][spender];
    }

    /**
     * @notice Get the token balance of the `owner`
     * @param owner The address of the account to query
     * @return The number of tokens owned by `owner`
     */
    function balanceOf(address owner) override external view returns (uint256) {
        return accountTokens[owner];
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @dev This also accrues interest in a transaction
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) override external returns (uint) {
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateCurrent());
        return FixedMath.mul_ScalarTruncate(exchangeRate, accountTokens[owner]);
    }

    /**
     * @notice Get a snapshot of the account's balances, and the cached exchange rate
     * @dev This is used by comptroller to more efficiently perform liquidity checks.
     * @param account Address of the account to snapshot
     * @return (possible error, token balance, borrow balance, exchange rate mantissa)
     */
    function getAccountSnapshot(address account) override external view returns (uint, uint, uint, uint) {
        return (
            NO_ERROR,
            accountTokens[account],
            borrowBalanceStoredInternal(account),
            exchangeRateStoredInternal()
        );
    }

    /**
     * @dev Function to simply retrieve block number
     *  This exists mainly for inheriting test contracts to stub this result.
     */
    function getBlockNumber() virtual internal view returns (uint) {
        return block.number;
    }

    /**
     * @notice Returns the current per-block borrow interest rate for this cToken
     * @return The borrow interest rate per block, scaled by 1e18
     */
    function borrowRatePerBlock() override external view returns (uint) {
        return interestRateModel.getBorrowRate(getCashPrior(), totalBorrows, totalReserves);
    }

    /**
     * @notice Returns the current per-block supply interest rate for this cToken
     * @return The supply interest rate per block, scaled by 1e18
     */
    function supplyRatePerBlock() override external view returns (uint) {
        return interestRateModel.getSupplyRate(getCashPrior(), totalBorrows, totalReserves, reserveFactorMantissa);
    }

    /**
     * @notice Returns the current total borrows plus accrued interest
     * @return The total borrows with interest
     */
    function totalBorrowsCurrent() override external nonReentrant returns (uint) {
        accrueInterest();
        return totalBorrows;
    }

    /**
     * @notice Accrue interest to updated borrowIndex and then calculate account's borrow balance using the updated borrowIndex
     * @param account The address whose balance should be calculated after updating borrowIndex
     * @return The calculated balance
     */
    function borrowBalanceCurrent(address account) override external nonReentrant returns (uint) {
        accrueInterest();
        return borrowBalanceStored(account);
    }

    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return The calculated balance
     */
    function borrowBalanceStored(address account) override public view returns (uint) {
        return borrowBalanceStoredInternal(account);
    }

    /**
     * @notice Return the borrow balance of account based on stored data
     * @param account The address whose balance should be calculated
     * @return (error code, the calculated balance or 0 if error code is non-zero)
     */
    function borrowBalanceStoredInternal(address account) internal view returns (uint) {
        /* Get borrowBalance and borrowIndex */
        BorrowSnapshot storage borrowSnapshot = accountBorrows[account];

        /* If borrowBalance = 0 then borrowIndex is likely also 0.
         * Rather than failing the calculation with a division by 0, we immediately return 0 in this case.
         */
        if (borrowSnapshot.principal == 0) {
            return 0;
        }

        /* Calculate new borrow balance using the interest index:
         *  recentBorrowBalance = borrower.borrowBalance * market.borrowIndex / borrower.borrowIndex
         */
        uint principalTimesIndex = borrowSnapshot.principal * borrowIndex;
        return principalTimesIndex / borrowSnapshot.interestIndex;
    }

    /**
     * @notice Accrue interest then return the up-to-date exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateCurrent() override public nonReentrant returns (uint) {
        accrueInterest();
        return exchangeRateStored();
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the CToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return Calculated exchange rate scaled by 1e18
     */
    function exchangeRateStored() override public view returns (uint) {
        return exchangeRateStoredInternal();
    }

    /**
     * @notice Calculates the exchange rate from the underlying to the CToken
     * @dev This function does not accrue interest before calculating the exchange rate
     * @return calculated exchange rate scaled by 1e18
     */
    function exchangeRateStoredInternal() virtual internal view returns (uint) {
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            /*
             * If there are no tokens minted:
             *  exchangeRate = initialExchangeRate
             */
            return initialExchangeRateMantissa;
        } else {
            /*
             * Otherwise:
             *  exchangeRate = (totalCash + totalBorrows - totalReserves) / totalSupply
             */
            uint totalCash = getCashPrior();
            uint cashPlusBorrowsMinusReserves = totalCash + totalBorrows - totalReserves;
            uint exchangeRate = cashPlusBorrowsMinusReserves * FixedMath.expScale / _totalSupply;

            return exchangeRate;
        }
    }

    /**
     * @notice Get cash balance of this cToken in the underlying asset
     * @return The quantity of underlying asset owned by this contract
     */
    function getCash() override external view returns (uint) {
        return getCashPrior();
    }

    /**
     * @notice Applies accrued interest to total borrows and reserves
     * @dev This calculates interest accrued from the last checkpointed block
     *   up to the current block and writes new checkpoint to storage.
     */
    function accrueInterest() virtual override public returns (uint) {
        /* Remember the initial block number */
        uint currentBlockNumber = getBlockNumber();
        uint accrualBlockNumberPrior = accrualBlockNumber;

        /* Short-circuit accumulating 0 interest */
        if (accrualBlockNumberPrior == currentBlockNumber) {
            return NO_ERROR;
        }

        /* Read the previous values out of storage */
        uint cashPrior = getCashPrior();
        uint borrowsPrior = totalBorrows;
        uint reservesPrior = totalReserves;
        uint borrowIndexPrior = borrowIndex;

        /* Calculate the current borrow interest rate */
        uint borrowRateMantissa = interestRateModel.getBorrowRate(cashPrior, borrowsPrior, reservesPrior);
        if (borrowRateMantissa > borrowRateMaxMantissa) revert BorrowRateTooHigh();

        /* Calculate the number of blocks elapsed since the last accrual */
        uint blockDelta = currentBlockNumber - accrualBlockNumberPrior;
        accrualBlockNumber = currentBlockNumber;

        /*
         * Calculate the interest accumulated into borrows and reserves and the new index:
         *  simpleInterestFactor = borrowRate * blockDelta
         *  interestAccumulated = simpleInterestFactor * totalBorrows
         *  totalBorrows = interestAccumulated + totalBorrows
         *  totalReserves = interestAccumulated * reserveFactor + totalReserves
         *  borrowIndex = simpleInterestFactor * borrowIndex + borrowIndex
         */

        FixedMath.Exp simpleInterestFactor = FixedMath.mul_(FixedMath.Exp.wrap(borrowRateMantissa), blockDelta);
        uint interestAccumulated = FixedMath.mul_ScalarTruncate(simpleInterestFactor, borrowsPrior);
        totalBorrows = interestAccumulated + borrowsPrior;
        totalReserves = FixedMath.mul_ScalarTruncateAddUInt(FixedMath.Exp.wrap(reserveFactorMantissa), interestAccumulated, reservesPrior);
        borrowIndex = FixedMath.mul_ScalarTruncateAddUInt(simpleInterestFactor, borrowIndexPrior, borrowIndexPrior);

        /* We emit an AccrueInterest event */
        emit AccrueInterest(cashPrior, interestAccumulated, borrowIndex, totalBorrows);

        return NO_ERROR;
    }

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     */
    function mintInternal(uint mintAmount) internal nonReentrant {
        accrueInterest();
        // mintFresh emits the actual Mint event if successful and logs on errors, so we don't need to
        mintFresh(msg.sender, mintAmount);
    }

    /**
     * @notice User supplies assets into the market and receives cTokens in exchange
     * @dev Assumes interest has already been accrued up to the current block
     * @param minter The address of the account which is supplying the assets
     * @param mintAmount The amount of the underlying asset to supply
     */
    function mintFresh(address minter, uint mintAmount) internal {
        /* Fail if mint not allowed */
        uint allowed = comptroller.mintAllowed(address(this), minter, mintAmount);
        if (allowed != 0) {
            revert MintComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert MintFreshnessCheck();
        }

        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         *  We call `doTransferIn` for the minter and the mintAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  `doTransferIn` reverts if anything goes wrong, since we can't be sure if
         *  side-effects occurred. The function returns the amount actually transferred,
         *  in case of a fee. On success, the cToken holds an additional `actualMintAmount`
         *  of cash.
         */
        uint actualMintAmount = doTransferIn(minter, mintAmount);

        /*
         * We get the current exchange rate and calculate the number of cTokens to be minted:
         *  mintTokens = actualMintAmount / exchangeRate
         */

        uint mintTokens = FixedMath.div_(actualMintAmount, exchangeRate);

        /*
         * We calculate the new total supply of cTokens and minter token balance, checking for overflow:
         *  totalSupplyNew = totalSupply + mintTokens
         *  accountTokensNew = accountTokens[minter] + mintTokens
         * And write them into storage
         */
        totalSupply = totalSupply + mintTokens;
        accountTokens[minter] = accountTokens[minter] + mintTokens;

        /* We emit a Mint event, and a Transfer event */
        emit Mint(minter, actualMintAmount, mintTokens);
        emit Transfer(address(this), minter, mintTokens);

        /* We call the defense hook */
        // unused function
        // comptroller.mintVerify(address(this), minter, actualMintAmount, mintTokens);
    }

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     */
    function redeemInternal(uint redeemTokens) internal nonReentrant {
        accrueInterest();
        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        redeemFresh(payable(msg.sender), redeemTokens, 0);
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to receive from redeeming cTokens
     */
    function redeemUnderlyingInternal(uint redeemAmount) internal nonReentrant {
        accrueInterest();
        // redeemFresh emits redeem-specific logs on errors, so we don't need to
        redeemFresh(payable(msg.sender), 0, redeemAmount);
    }

    /**
     * @notice User redeems cTokens in exchange for the underlying asset
     * @dev Assumes interest has already been accrued up to the current block
     * @param redeemer The address of the account which is redeeming the tokens
     * @param redeemTokensIn The number of cTokens to redeem into underlying (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     * @param redeemAmountIn The number of underlying tokens to receive from redeeming cTokens (only one of redeemTokensIn or redeemAmountIn may be non-zero)
     */
    function redeemFresh(address payable redeemer, uint redeemTokensIn, uint redeemAmountIn) internal {
        if (redeemTokensIn != 0 && redeemAmountIn != 0) revert RedeemTokensInOrRedeemAmountInShouldBeZero();

        /* exchangeRate = invoke Exchange Rate Stored() */
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());

        uint redeemTokens;
        uint redeemAmount;
        /* If redeemTokensIn > 0: */
        if (redeemTokensIn > 0) {
            /*
             * We calculate the exchange rate and the amount of underlying to be redeemed:
             *  redeemTokens = redeemTokensIn
             *  redeemAmount = redeemTokensIn x exchangeRateCurrent
             */
            redeemTokens = redeemTokensIn;
            redeemAmount = FixedMath.mul_ScalarTruncate(exchangeRate, redeemTokensIn);
        } else {
            /*
             * We get the current exchange rate and calculate the amount to be redeemed:
             *  redeemTokens = redeemAmountIn / exchangeRate
             *  redeemAmount = redeemAmountIn
             */
            redeemTokens = FixedMath.div_(redeemAmountIn, exchangeRate);
            redeemAmount = redeemAmountIn;
        }

        /* Fail if redeem not allowed */
        uint allowed = comptroller.redeemAllowed(address(this), redeemer, redeemTokens);
        if (allowed != 0) {
            revert RedeemComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RedeemFreshnessCheck();
        }

        /* Fail gracefully if protocol has insufficient cash */
        if (getCashPrior() < redeemAmount) {
            revert RedeemTransferOutNotPossible();
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)


        /*
         * We write the previously calculated values into storage.
         *  Note: Avoid token reentrancy attacks by writing reduced supply before external transfer.
         */
        totalSupply = totalSupply - redeemTokens;
        accountTokens[redeemer] = accountTokens[redeemer] - redeemTokens;

        /*
         * We invoke doTransferOut for the redeemer and the redeemAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken has redeemAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(redeemer, redeemAmount);

        /* We emit a Transfer event, and a Redeem event */
        emit Transfer(redeemer, address(this), redeemTokens);
        emit Redeem(redeemer, redeemAmount, redeemTokens);

        /* We call the defense hook */
        comptroller.redeemVerify(address(this), redeemer, redeemAmount, redeemTokens);
    }

    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      */
    function borrowInternal(uint borrowAmount) internal nonReentrant {
        accrueInterest();
        // borrowFresh emits borrow-specific logs on errors, so we don't need to
        borrowFresh(payable(msg.sender), borrowAmount);
    }

    /**
      * @notice Users borrow assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      */
    function borrowFresh(address payable borrower, uint borrowAmount) internal {
        /* Fail if borrow not allowed */
        uint allowed = comptroller.borrowAllowed(address(this), borrower, borrowAmount);
        if (allowed != 0) {
            revert BorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert BorrowFreshnessCheck();
        }

        /* Fail gracefully if protocol has insufficient underlying cash */
        if (getCashPrior() < borrowAmount) {
            revert BorrowCashNotAvailable();
        }

        /*
         * We calculate the new borrower and total borrow balances, failing on overflow:
         *  accountBorrowNew = accountBorrow + borrowAmount
         *  totalBorrowsNew = totalBorrows + borrowAmount
         */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);
        uint accountBorrowsNew = accountBorrowsPrev + borrowAmount;
        uint totalBorrowsNew = totalBorrows + borrowAmount;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We write the previously calculated values into storage.
         *  Note: Avoid token reentrancy attacks by writing increased borrow before external transfer.
        `*/
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /*
         * We invoke doTransferOut for the borrower and the borrowAmount.
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken borrowAmount less of cash.
         *  doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
         */
        doTransferOut(borrower, borrowAmount);

        /* We emit a Borrow event */
        emit Borrow(borrower, borrowAmount, accountBorrowsNew, totalBorrowsNew);
    }

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     */
    function repayBorrowInternal(uint repayAmount) internal nonReentrant {
        accrueInterest();
        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        repayBorrowFresh(msg.sender, msg.sender, repayAmount);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     */
    function repayBorrowBehalfInternal(address borrower, uint repayAmount) internal nonReentrant {
        accrueInterest();
        // repayBorrowFresh emits repay-borrow-specific logs on errors, so we don't need to
        repayBorrowFresh(msg.sender, borrower, repayAmount);
    }

    /**
     * @notice Borrows are repaid by another user (possibly the borrower).
     * @param payer the account paying off the borrow
     * @param borrower the account with the debt being payed off
     * @param repayAmount the amount of underlying tokens being returned, or -1 for the full outstanding amount
     * @return (uint) the actual repayment amount.
     */
    function repayBorrowFresh(address payer, address borrower, uint repayAmount) internal returns (uint) {
        /* Fail if repayBorrow not allowed */
        uint allowed = comptroller.repayBorrowAllowed(address(this), payer, borrower, repayAmount);
        if (allowed != 0) {
            revert RepayBorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RepayBorrowFreshnessCheck();
        }

        /* We fetch the amount the borrower owes, with accumulated interest */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);

        /* If repayAmount == -1, repayAmount = accountBorrows */
        uint repayAmountFinal = repayAmount == type(uint).max ? accountBorrowsPrev : repayAmount;

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /*
         * We call doTransferIn for the payer and the repayAmount
         *  Note: The cToken must handle variations between ERC-20 and ETH underlying.
         *  On success, the cToken holds an additional repayAmount of cash.
         *  doTransferIn reverts if anything goes wrong, since we can't be sure if side effects occurred.
         *   it returns the amount actually transferred, in case of a fee.
         */
        uint actualRepayAmount = doTransferIn(payer, repayAmountFinal);

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        uint accountBorrowsNew = accountBorrowsPrev - actualRepayAmount;
        uint totalBorrowsNew = totalBorrows - actualRepayAmount;

        /* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /* We emit a RepayBorrow event */
        emit RepayBorrow(payer, borrower, actualRepayAmount, accountBorrowsNew, totalBorrowsNew);

        return actualRepayAmount;
    }

    function repayWithDeposit(address borrower, uint repayAmount) external {
        accrueInterest();
        address repayer = msg.sender;
        /* Fail if repayBorrow not allowed */
        uint allowed = comptroller.repayBorrowAllowed(address(this), repayer, borrower, repayAmount);
        if (allowed != 0) {
            revert RepayBorrowComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert RepayBorrowFreshnessCheck();
        }

        /* We fetch the amount the borrower owes, with accumulated interest */
        uint accountBorrowsPrev = borrowBalanceStoredInternal(borrower);

        /* If repayAmount == -1, repayAmount = accountBorrows */
        uint repayAmountFinal = repayAmount == type(uint).max ? accountBorrowsPrev : repayAmount;

        /* exchangeRate = invoke Exchange Rate Stored() */
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());

        uint redeemTokens = FixedMath.div_(repayAmountFinal, exchangeRate);

        if (repayer != borrower) {
            allowed = comptroller.redeemAllowed(address(this), repayer, redeemTokens);
            if (allowed != 0) {
                revert RedeemComptrollerRejection(allowed);
            }
        }
       
        totalSupply = totalSupply - redeemTokens;
        accountTokens[repayer] = accountTokens[repayer] - redeemTokens;

        /*
         * We calculate the new borrower and total borrow balances, failing on underflow:
         *  accountBorrowsNew = accountBorrows - actualRepayAmount
         *  totalBorrowsNew = totalBorrows - actualRepayAmount
         */
        uint accountBorrowsNew = accountBorrowsPrev - repayAmountFinal;
        uint totalBorrowsNew = totalBorrows - repayAmountFinal;

        /* We write the previously calculated values into storage */
        accountBorrows[borrower].principal = accountBorrowsNew;
        accountBorrows[borrower].interestIndex = borrowIndex;
        totalBorrows = totalBorrowsNew;

        /* We emit a Transfer event, and a Redeem event */
        emit Transfer(repayer, address(this), redeemTokens);        
        /* We emit a RepayBorrow event */
        emit RepayBorrow(repayer, borrower, repayAmountFinal, accountBorrowsNew, totalBorrowsNew);

    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     */
    function liquidateBorrowInternal(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) internal nonReentrant {
        accrueInterest();

        uint error = cTokenCollateral.accrueInterest();
        if (error != NO_ERROR) {
            // accrueInterest emits logs on errors, but we still want to log the fact that an attempted liquidation failed
            revert LiquidateAccrueCollateralInterestFailed(error);
        }

        // liquidateBorrowFresh emits borrow-specific logs on errors, so we don't need to
        liquidateBorrowFresh(msg.sender, borrower, repayAmount, cTokenCollateral);
    }

    /**
     * @notice The liquidator liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param liquidator The address repaying the borrow and seizing collateral
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     * @param repayAmount The amount of the underlying borrowed asset to repay
     */
    function liquidateBorrowFresh(address liquidator, address borrower, uint repayAmount, CTokenInterface cTokenCollateral) internal {
        /* Fail if liquidate not allowed */
        uint allowed = comptroller.liquidateBorrowAllowed(address(this), address(cTokenCollateral), liquidator, borrower, repayAmount);
        if (allowed != 0) {
            revert LiquidateComptrollerRejection(allowed);
        }

        /* Verify market's block number equals current block number */
        if (accrualBlockNumber != getBlockNumber()) {
            revert LiquidateFreshnessCheck();
        }

        /* Verify cTokenCollateral market's block number equals current block number */
        if (cTokenCollateral.accrualBlockNumber() != getBlockNumber()) {
            revert LiquidateCollateralFreshnessCheck();
        }

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            revert LiquidateLiquidatorIsBorrower();
        }

        /* Fail if repayAmount = 0 */
        if (repayAmount == 0) {
            revert LiquidateCloseAmountIsZero();
        }

        /* Fail if repayAmount = -1 */
        if (repayAmount == type(uint).max) {
            revert LiquidateCloseAmountIsUintMax();
        }

        /* Fail if repayBorrow fails */
        uint actualRepayAmount = repayBorrowFresh(liquidator, borrower, repayAmount);

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We calculate the number of collateral tokens that will be seized */
        (, uint seizeTokens) = comptroller.liquidateCalculateSeizeTokens(address(this), address(cTokenCollateral), actualRepayAmount);

        if (comptroller.isValidSmartAccount(borrower)) {
            ISmartAccount smartBorrower = ISmartAccount(borrower);
            uint accountCollateralValue = smartBorrower.getNonStandardCollateralAssetValue();
            if (accountCollateralValue < seizeTokens) revert LiquidateSizeTooMuch();
            smartBorrower.liquidate(borrower, liquidator);
            return;
        }
        /* Revert if borrower collateral token balance < seizeTokens */
        if (cTokenCollateral.balanceOf(borrower) < seizeTokens) revert LiquidateSizeTooMuch();

        // If this is also the collateral, run seizeInternal to avoid re-entrancy, otherwise make an external call
        if (address(cTokenCollateral) == address(this)) {
            seizeInternal(address(this), liquidator, borrower, seizeTokens);
        } else {
            cTokenCollateral.seize(liquidator, borrower, seizeTokens);
        }

        /* We emit a LiquidateBorrow event */
        emit LiquidateBorrow(liquidator, borrower, actualRepayAmount, address(cTokenCollateral), seizeTokens);
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Will fail unless called by another cToken during the process of liquidation.
     *  Its absolutely critical to use msg.sender as the borrowed cToken and not a parameter.
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of cTokens to seize
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function seize(address liquidator, address borrower, uint seizeTokens) override external nonReentrant returns (uint) {
        seizeInternal(msg.sender, liquidator, borrower, seizeTokens);

        return NO_ERROR;
    }

    /**
     * @notice Transfers collateral tokens (this market) to the liquidator.
     * @dev Called only during an in-kind liquidation, or by liquidateBorrow during the liquidation of another CToken.
     *  Its absolutely critical to use msg.sender as the seizer cToken and not a parameter.
     * @param seizerToken The contract seizing the collateral (i.e. borrowed cToken)
     * @param liquidator The account receiving seized collateral
     * @param borrower The account having collateral seized
     * @param seizeTokens The number of cTokens to seize
     */
    function seizeInternal(address seizerToken, address liquidator, address borrower, uint seizeTokens) internal {
        /* Fail if seize not allowed */
        uint allowed = comptroller.seizeAllowed(address(this), seizerToken, liquidator, borrower, seizeTokens);
        if (allowed != 0) {
            revert LiquidateSeizeComptrollerRejection(allowed);
        }

        /* Fail if borrower = liquidator */
        if (borrower == liquidator) {
            revert LiquidateSeizeLiquidatorIsBorrower();
        }

        /*
         * We calculate the new borrower and liquidator token balances, failing on underflow/overflow:
         *  borrowerTokensNew = accountTokens[borrower] - seizeTokens
         *  liquidatorTokensNew = accountTokens[liquidator] + seizeTokens
         */
        uint protocolSeizeTokens = FixedMath.mul_(seizeTokens, FixedMath.Exp.wrap(protocolSeizeShareMantissa));
        uint liquidatorSeizeTokens = seizeTokens - protocolSeizeTokens;
        FixedMath.Exp exchangeRate = FixedMath.Exp.wrap(exchangeRateStoredInternal());
        uint protocolSeizeAmount = FixedMath.mul_ScalarTruncate(exchangeRate, protocolSeizeTokens);
        uint totalReservesNew = totalReserves + protocolSeizeAmount;


        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        /* We write the calculated values into storage */
        totalReserves = totalReservesNew;
        totalSupply = totalSupply - protocolSeizeTokens;
        accountTokens[borrower] = accountTokens[borrower] - seizeTokens;
        accountTokens[liquidator] = accountTokens[liquidator] + liquidatorSeizeTokens;

        /* Emit a Transfer event */
        emit Transfer(borrower, liquidator, liquidatorSeizeTokens);
        emit Transfer(borrower, address(this), protocolSeizeTokens);
        emit ReservesAdded(address(this), protocolSeizeAmount, totalReservesNew);
    }


    /*** Admin Functions ***/

    /**
      * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
      * @param newPendingAdmin New pending admin.
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setPendingAdmin(address payable newPendingAdmin) override external returns (uint) {
        // Check caller = admin
        if (msg.sender != admin) {
            revert SetPendingAdminOwnerCheck();
        }

        emit NewPendingAdmin(pendingAdmin, newPendingAdmin);

        // Store pendingAdmin with value newPendingAdmin
        pendingAdmin = newPendingAdmin;

        return NO_ERROR;
    }

    /**
      * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
      * @dev Admin function for pending admin to accept role and update admin
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _acceptAdmin() override external returns (uint) {
        // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
        if (msg.sender != pendingAdmin || pendingAdmin == address(0)) {
            revert AcceptAdminPendingAdminCheck();
        }

        emit NewAdmin(admin, pendingAdmin);
        emit NewPendingAdmin(pendingAdmin, payable(address(0)));
     
        // Store admin with value pendingAdmin
        admin = pendingAdmin;

        // Clear the pending value
        pendingAdmin = payable(address(0));

        return NO_ERROR;
    }

    /**
      * @notice Sets a new comptroller for the market
      * @dev Admin function to set a new comptroller
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setComptroller(ComptrollerInterface newComptroller) override public returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            revert SetComptrollerOwnerCheck();
        }

        // Ensure invoke comptroller.isComptroller() returns true
        if(!newComptroller.isComptroller()) revert NotComptroller();

        emit NewComptroller(comptroller, newComptroller);

        // Set market's comptroller to newComptroller
        comptroller = newComptroller;

        return NO_ERROR;
    }

    /**
      * @notice accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh
      * @dev Admin function to accrue interest and set a new reserve factor
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setReserveFactor(uint newReserveFactorMantissa) override external nonReentrant returns (uint) {
        accrueInterest();
        // _setReserveFactorFresh emits reserve-factor-specific logs on errors, so we don't need to.
        return _setReserveFactorFresh(newReserveFactorMantissa);
    }

    /**
      * @notice Sets a new reserve factor for the protocol (*requires fresh interest accrual)
      * @dev Admin function to set a new reserve factor
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function _setReserveFactorFresh(uint newReserveFactorMantissa) internal returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            revert SetReserveFactorAdminCheck();
        }

        // Check newReserveFactor ≤ maxReserveFactor
        if (newReserveFactorMantissa > reserveFactorMaxMantissa) {
            revert SetReserveFactorBoundsCheck();
        }

        emit NewReserveFactor(reserveFactorMantissa, newReserveFactorMantissa);

        reserveFactorMantissa = newReserveFactorMantissa;

        return NO_ERROR;
    }

    /**
     * @notice Accrues interest and reduces reserves by transferring to admin
     * @param reduceAmount Amount of reduction to reserves
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _reduceReserves(uint reduceAmount) override external nonReentrant returns (uint) {
        accrueInterest();
        // _reduceReservesFresh emits reserve-reduction-specific logs on errors, so we don't need to.
        return _reduceReservesFresh(reduceAmount);
    }

    /**
     * @notice Reduces reserves by transferring to admin
     * @dev Requires fresh interest accrual
     * @param reduceAmount Amount of reduction to reserves
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _reduceReservesFresh(uint reduceAmount) internal returns (uint) {
        // Fail gracefully if protocol has insufficient underlying cash
        if (getCashPrior() < reduceAmount) {
            revert ReduceReservesCashNotAvailable();
        }

        // Check reduceAmount ≤ reserves[n] (totalReserves)
        if (reduceAmount > totalReserves) {
            revert ReduceReservesCashValidation();
        }

        /////////////////////////
        // EFFECTS & INTERACTIONS
        // (No safe failures beyond this point)

        totalReserves = totalReserves - reduceAmount;

        // doTransferOut reverts if anything goes wrong, since we can't be sure if side effects occurred.
        doTransferOut(admin, reduceAmount);

        emit ReservesReduced(admin, reduceAmount, totalReserves);

        return NO_ERROR;
    }

    /**
     * @notice accrues interest and updates the interest rate model using _setInterestRateModelFresh
     * @dev Admin function to accrue interest and update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setInterestRateModel(InterestRateModel newInterestRateModel) override public returns (uint) {
        accrueInterest();
        // _setInterestRateModelFresh emits interest-rate-model-update-specific logs on errors, so we don't need to.
        return _setInterestRateModelFresh(newInterestRateModel);
    }

    /**
     * @notice updates the interest rate model (*requires fresh interest accrual)
     * @dev Admin function to update the interest rate model
     * @param newInterestRateModel the new interest rate model to use
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _setInterestRateModelFresh(InterestRateModel newInterestRateModel) internal returns (uint) {
        // Check caller is admin
        if (msg.sender != admin) {
            revert SetInterestRateModelOwnerCheck();
        }

        // Ensure invoke newInterestRateModel.isInterestRateModel() returns true
        if (!newInterestRateModel.isInterestRateModel()) revert InvalidContractAddress();

        // Emit NewMarketInterestRateModel(oldInterestRateModel, newInterestRateModel)
        emit NewMarketInterestRateModel(interestRateModel, newInterestRateModel);

        // Set the interest rate model to newInterestRateModel
        interestRateModel = newInterestRateModel;
   
        return NO_ERROR;
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying owned by this contract
     */
    function getCashPrior() virtual internal view returns (uint);

    /**
     * @dev Performs a transfer in, reverting upon failure. Returns the amount actually transferred to the protocol, in case of a fee.
     *  This may revert due to insufficient balance or insufficient allowance.
     */
    function doTransferIn(address from, uint amount) virtual internal returns (uint);

    /**
     * @dev Performs a transfer out, ideally returning an explanatory error code upon failure rather than reverting.
     *  If caller has not called checked protocol's balance, may revert due to insufficient cash held in the contract.
     *  If caller has checked protocol's balance, and verified it is >= amount, this should not revert in normal conditions.
     */
    function doTransferOut(address payable to, uint amount) virtual internal;

    function isNativeToken() external pure virtual returns (bool) {
        return false;
    }
    /*** Reentrancy Guard ***/

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     */
    modifier nonReentrant() {
        require(_notEntered, "re-entered");
        _notEntered = false;
        _;
        _notEntered = true; // get a gas-refund post-Istanbul
    }
}


// File contracts/Interfaces/IWETH.sol


pragma solidity ^0.8.10;

interface IWETH {
  function balanceOf(address user) external returns (uint);

  function approve(address to, uint value) external returns (bool);

  function transfer(address to, uint value) external returns (bool);

  function transferFrom(address src, address dst, uint256 amount) external returns (bool success);

  function deposit() external payable;

  function withdraw(uint) external;
}


// File contracts/CWrappedNative.sol


pragma solidity ^0.8.10;


/**
 * @title Compound's CErc20 Contract
 * @notice CTokens which wrap an EIP-20 underlying
 * @author Compound
 */
contract CWrappedNative is CToken, CErc20Storage {
    /**
     * @notice Initialize the new money market
     * @param underlying_ The address of the underlying asset
     * @param comptroller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     */
    function initialize(address underlying_,
                        ComptrollerInterface comptroller_,
                        InterestRateModel interestRateModel_,
                        uint initialExchangeRateMantissa_,
                        string memory name_,
                        string memory symbol_,
                        uint8 decimals_) public {
        // CToken initialize does the bulk of the work
        super.initialize(comptroller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_);

        // Set underlying and sanity check it
        underlying = underlying_;
        EIP20Interface(underlying).totalSupply();
        IWETH(underlying);
    }

    /*** User Interface ***/

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Reverts upon any failure
     */
    function mint() external payable {
        mintInternal(msg.value);
    }
    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeem(uint redeemTokens) external returns (uint) {
        redeemInternal(redeemTokens);
        return NO_ERROR;
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemUnderlying(uint redeemAmount) external returns (uint) {
        redeemUnderlyingInternal(redeemAmount);
        return NO_ERROR;
    }

    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
      */
    function borrow(uint borrowAmount) external returns (uint) {
        borrowInternal(borrowAmount);
        return NO_ERROR;
    }

    /**
     * @notice Sender repays their own borrow
     */
    function repayBorrow() external payable {
        repayBorrowInternal(msg.value);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     */
    function repayBorrowBehalf(address borrower) external payable {
        repayBorrowBehalfInternal(borrower, msg.value);
    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @dev Reverts upon any failure
     * @param borrower The borrower of this cToken to be liquidated
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     */
    function liquidateBorrow(address borrower, CToken cTokenCollateral) external payable {
        liquidateBorrowInternal(borrower, msg.value, cTokenCollateral);
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying tokens owned by this contract
     */
    function getCashPrior() internal view override returns (uint) {
        EIP20Interface token = EIP20Interface(underlying);
        return token.balanceOf(address(this));
    }

    /**
     * @notice Perform the actual transfer in, which is a no-op
     * @param from Address sending the Ether
     * @param amount Amount of Ether being sent
     * @return The actual amount of Ether transferred
     */
    function doTransferIn(address from, uint amount) internal override returns (uint) {
        // Sanity checks
        require(msg.sender == from, "sender mismatch");
        require(msg.value == amount, "value mismatch");
        IWETH nativeWrapper = IWETH(underlying);
        nativeWrapper.deposit{value: amount}();
        return amount;
    }

    function doTransferOut(address payable to, uint amount) internal override {
        /* Send the Ether, with minimal gas and revert on failure */
        IWETH nativeWrapper = IWETH(underlying);
        nativeWrapper.withdraw(amount);
        to.transfer(amount);
    }

    function doFlashLoanTransferOut(address payable receiver, address wrapperToken, uint amount) internal {
        require(wrapperToken == underlying, "!token");

        IWETH nativeWrapper = IWETH(underlying);
        nativeWrapper.transfer(receiver, amount);
    }

    function doFlashLoanTransferIn(address receiver, address wrapperToken, uint amount) internal {
        require(wrapperToken == underlying, "!token");
        IWETH nativeWrapper = IWETH(underlying);
        uint balanceBefore = nativeWrapper.balanceOf(address(this));

        nativeWrapper.transferFrom(receiver, address(this), amount);

        uint balanceAfter = nativeWrapper.balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "TRANSFER_IN_OVERFLOW");
        require(balanceAfter - balanceBefore == amount, "!amount");
    }

    function isNativeToken() external pure override returns (bool) {
        return true;
    }

    function validateFlashloanToken(address token) view internal {
        require(underlying == token, "!flashloan token");
    }

    receive() external payable {
        require(msg.sender == underlying, "!wrapped native");
    }
}


// File contracts/Fevm/MinerSmartOwner.sol


pragma solidity ^0.8.10;







contract MinerSmartOwner is ISmartAccount {
    error Unauthorized();
    error IllegalArgument();
    error InvalidAddress();
    error InvalidActorId();
    error MinerAlreadyBound();
    error MinerNotBound();
    error NegativeValueNotAllowed();

    event GovernorTransferred(address oldGovernor, address newGovernor);
    event Invoked(address indexed invoker, address indexed target, uint indexed value, bytes data);

    CommonTypes.FilActorId public minerId;
    using MinerAPI for CommonTypes.FilActorId;

    address public governor;
    CWrappedNative public lendingPool; 

    modifier onlyGovernor {
        if (msg.sender != governor) revert Unauthorized();
        _;
    }
    
    constructor(address governor_, address payable lendingPool_) {
        governor = governor_;
        lendingPool = CWrappedNative(lendingPool_);
    }

    function transferGovernor(address newGovernor) external onlyGovernor {
        // TODO: liquidity check, not allow to transfer if not all borrow got repaid
        _transferGovernor(newGovernor);
    }

    // TODO: permission check
    function liquidate(address borrower, address liquidator) external {
        if (borrower != address(this)) revert IllegalArgument();
        _transferGovernor(liquidator);
    }

    function _transferGovernor(address newGovernor) internal {
        if (newGovernor == address(0)) revert IllegalArgument();
        
        emit GovernorTransferred(governor, newGovernor);

        governor = newGovernor;
    }

    function withdraw(address token, uint amount, address to) external onlyGovernor {
        if (isNativeToken(token)) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) {
                revert InvalidAddress();
            }
        } else {
            EIP20Interface(token).transfer(to, amount);
        }
    }

    function borrow(uint amount) external onlyGovernor {
        lendingPool.borrow(amount);
    }

    function borrowBalance() public returns (uint) {
        return lendingPool.borrowBalanceCurrent(address(this));
    }

    function repayBorrow() public payable onlyGovernor {
        lendingPool.repayBorrow{value: msg.value}();
    }

    function repayWithDeposit(uint repayAmount) external onlyGovernor {
        lendingPool.repayWithDeposit(address(this), repayAmount);
    }

    function getMinerOwner() external returns (CommonTypes.FilAddress memory currentOwner, CommonTypes.FilAddress memory proposedOwner) {
        MinerTypes.GetOwnerReturn memory getOwnerReturn = minerId.getOwner();
        currentOwner = getOwnerReturn.owner;
        proposedOwner = getOwnerReturn.proposed;
    }

    function acceptMinerOwnership(uint64 targetMinerActorId) external onlyGovernor {
        if (targetMinerActorId == 0) revert InvalidActorId();
        if (CommonTypes.FilActorId.unwrap(minerId) != 0) revert MinerAlreadyBound();

        minerId = CommonTypes.FilActorId.wrap(targetMinerActorId);
        uint64 ownerActorId = PrecompilesAPI.resolveEthAddress(address(this));
        minerId.changeOwnerAddress(FilAddresses.fromActorID(ownerActorId));
    }

    function transferMinerOwnership(CommonTypes.FilAddress memory newMinerOwner) external onlyGovernor {
        minerId.changeOwnerAddress(newMinerOwner);
        minerId = CommonTypes.FilActorId.wrap(0);
    }

    function transferMinerOwnership(address newMinerOwner) external onlyGovernor {
        if (newMinerOwner == address(0)) revert IllegalArgument();
        if (CommonTypes.FilActorId.unwrap(minerId) == 0) revert MinerNotBound();

        uint64 ownerActorId = PrecompilesAPI.resolveEthAddress(address(newMinerOwner));
        minerId.changeOwnerAddress(FilAddresses.fromActorID(ownerActorId));
        minerId = CommonTypes.FilActorId.wrap(0);
    }

    function isControllingAddress(address controller) external returns (bool) {
        return minerId.isControllingAddress(FilAddresses.fromEthAddress(controller));
    }

    function getSectorSize() external returns (uint64) {
        return minerId.getSectorSize();
    }

    function getAvailableBalance() external returns (CommonTypes.BigInt memory) {
        return minerId.getAvailableBalance();
    }

    function getVestingFunds() external returns (MinerTypes.GetVestingFundsReturn memory) {
        return minerId.getVestingFunds();
    }

    function changeBeneficiary(MinerTypes.ChangeBeneficiaryParams memory params) external onlyGovernor {
        minerId.changeBeneficiary(params);
    }

    function getBeneficiary() external returns (MinerTypes.GetBeneficiaryReturn memory) {
        return minerId.getBeneficiary();
    }

    function changeWorkerAddress(MinerTypes.ChangeWorkerAddressParams memory params) external onlyGovernor {
        minerId.changeWorkerAddress(params);
    }

    function changePeerId(CommonTypes.FilAddress memory newId) external onlyGovernor {
        minerId.changePeerId(newId);
    }

    function changeMultiaddresses(MinerTypes.ChangeMultiaddrsParams memory params) external onlyGovernor {
        minerId.changeMultiaddresses(params);
    }

    function repayDebt() external onlyGovernor {
        minerId.repayDebt();
    }

    function confirmChangeWorkerAddress() external onlyGovernor {
        minerId.confirmChangeWorkerAddress();
    }

    function getPeerId() external returns (CommonTypes.FilAddress memory) {
        return minerId.getPeerId();
    }

    function getMultiaddresses() external returns (MinerTypes.GetMultiaddrsReturn memory) {
        return minerId.getMultiaddresses();
    }

    function withdrawBalanceFromMiner(CommonTypes.BigInt memory amount) external onlyGovernor returns (uint) {
        uint withdrawAmount = toUint256(minerId.withdrawBalance(amount));
        uint borrowedAmount = borrowBalance();
        uint repayAmount = withdrawAmount/2;
        if (repayAmount > borrowedAmount) {
            repayAmount = borrowedAmount;
        }
        repayBorrow();
        return withdrawAmount;
    }

    function getNonStandardCollateralAssetValue() external pure returns(uint) {
        return 100 * (10 ** 18);
    }

    function toUint256(CommonTypes.BigInt memory value) internal pure returns (uint256) {
        if (value.neg) {
            revert NegativeValueNotAllowed();
        }

        // BigNumber memory max = BigNumbers.init(MAX_UINT, false);
        // BigNumber memory bigNumValue = BigNumbers.init(value.val, value.neg);
        // if (BigNumbers.gt(bigNumValue, max)) {
        //     return (0, true);
        // }

        return (uint256(bytes32(value.val)));
    }

    function isNativeToken(address token) internal pure returns (bool) {
        return token == address(0);
    }

    function filAdressToAddress(CommonTypes.FilAddress memory addr) public pure returns (address) {
        bytes memory data = addr.data;
        if (data.length != 22) {
            revert InvalidAddress();
        }
        bytes20 addressBytes;
        assembly {
            addressBytes := mload(add(data, 0x22))
        }
        return address(addressBytes);
    }


    // function invoke(address target, bytes calldata data) external payable onlyGovernor returns (bytes memory result) {
    //     bool success;
    //     (success, result) = target.call{value: msg.value}(data);
    //     if (!success) {
    //         // solhint-disable-next-line no-inline-assembly
    //         assembly {
    //             returndatacopy(0, 0, returndatasize())
    //             revert(0, returndatasize())
    //         }
    //     }
    //     emit Invoked(msg.sender, target, msg.value, data);
    // }

    receive() external payable {
    }
}


// File contracts/Fevm/FilSmartOwnerFactory.sol


pragma solidity ^0.8.10;


contract FilSmartOwnerFactory is ISmartAccountFactory {
    mapping(address => bool) public smartOwnerPool;

    event SmartOwnerCreated(address creator, address newSmartOwner);

    function createSmartOwner(address governor, address payable lendingPool) external returns(address) {
        MinerSmartOwner newSmartOwner = new MinerSmartOwner(governor, lendingPool);
        smartOwnerPool[address(newSmartOwner)] = true;

        emit SmartOwnerCreated(address(msg.sender), address(newSmartOwner));

        return address(newSmartOwner);
    }

    function isValidSmartAccount(address smartOwner) external view returns (bool) {
        return smartOwnerPool[smartOwner];
    }
}
