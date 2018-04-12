--
--------------------------------------------------------------------------------
--  FILE:  encoder.lua
--  DESCRIPTION:  protoc-gen-lua
--      Google's Protocol Buffers project, ported to lua.
--      https://code.google.com/p/protoc-gen-lua/
--
--      Copyright (c) 2010 , 林卓毅 (Zhuoyi Lin) netsnail@gmail.com
--      All rights reserved.
--
--      Use, modification and distribution are subject to the "New BSD License"
--      as listed at <url: http://www.opensource.org/licenses/bsd-license.php >.
--
--  COMPANY:  NetEase
--  CREATED:  2010年07月29日 19时30分46秒 CST
--------------------------------------------------------------------------------
--

local pb = require "pb"

local wire_format = require "wire_format"

-- module("encoder")
local encoder = {}
local _M = encoder

local function _VarintSize(value)
    if value <= 0x7f then return 1 end
    if value <= 0x3fff then return 2 end
    if value <= 0x1fffff then return 3 end
    if value <= 0xfffffff then return 4 end
    return 5 
end

local function _SignedVarintSize(value)
    if value < 0 then return 10 end
    if value <= 0x7f then return 1 end
    if value <= 0x3fff then return 2 end
    if value <= 0x1fffff then return 3 end
    if value <= 0xfffffff then return 4 end
    return 5
end

local function _TagSize(field_number)
  return _VarintSize(wire_format.PackTag(field_number, 0))
end

local function _SimpleSizer(compute_value_size)
    return function(field_number, is_repeated, is_packed)
        local tag_size = _TagSize(field_number)
        if is_packed then
            local VarintSize = _VarintSize
            return function(value)
                local result = 0
                for _, element in ipairs(value) do
                    result = result + compute_value_size(element)
                end
                return result + VarintSize(result) + tag_size
            end
        elseif is_repeated then
            return function(value)
                local result = tag_size * #value
                for _, element in ipairs(value) do
                    result = result + compute_value_size(element)
                end
                return result
            end
        else
            return function (value)
                return tag_size + compute_value_size(value)
            end
        end
    end
end

local function _ModifiedSizer(compute_value_size, modify_value)
    return function (field_number, is_repeated, is_packed)
        local tag_size = _TagSize(field_number)
        if is_packed then
            local VarintSize = _VarintSize
            return function (value)
                local result = 0
                for _, element in ipairs(value) do
                    result = result + compute_value_size(modify_value(element))
                end
                return result + VarintSize(result) + tag_size
            end
        elseif is_repeated then
            return function (value)
                local result = tag_size * #value
                for _, element in ipairs(value) do
                    result = result + compute_value_size(modify_value(element))
                end
                return result
            end
        else
            return function (value)
                return tag_size + compute_value_size(modify_value(value))
            end
        end
    end
end

local function _FixedSizer(value_size)
    return function (field_number, is_repeated, is_packed)
        local tag_size = _TagSize(field_number)
        if is_packed then
            local VarintSize = _VarintSize
            return function (value)
                local result = #value * value_size
                return result + VarintSize(result) + tag_size
            end
        elseif is_repeated then
            local element_size = value_size + tag_size
            return function(value)
                return #value * element_size
            end
        else
            local field_size = value_size + tag_size
            return function (value)
                return field_size
            end
        end
    end
end

_M.Int32Sizer = _SimpleSizer(_SignedVarintSize)
_M.Int64Sizer = _M.Int32Sizer
_M.EnumSizer = _M.Int32Sizer

_M.UInt32Sizer = _SimpleSizer(_VarintSize)
_M.UInt64Sizer = _M.UInt32Sizer 

_M.SInt32Sizer = _ModifiedSizer(_SignedVarintSize, wire_format.ZigZagEncode32)
_M.SInt64Sizer = _ModifiedSizer(_SignedVarintSize, wire_format.ZigZagEncode64)

_M.Fixed32Sizer = _FixedSizer(4) 
_M.SFixed32Sizer = _M.Fixed32Sizer
_M.FloatSizer = _M.Fixed32Sizer

_M.Fixed64Sizer = _FixedSizer(8) 
_M.SFixed64Sizer = _M.Fixed64Sizer
_M.DoubleSizer = _M.Fixed64Sizer

_M.BoolSizer = _FixedSizer(1)


function _M.StringSizer(field_number, is_repeated, is_packed)
    local tag_size = _TagSize(field_number)
    local VarintSize = _VarintSize
    assert(not is_packed)
    if is_repeated then
        return function(value)
            local result = tag_size * #value
            for _, element in ipairs(value) do
                local l = #element
                result = result + VarintSize(l) + l
            end
            return result
        end
    else
        return function(value)
            local l = #value
            return tag_size + VarintSize(l) + l
        end
    end
end

function _M.BytesSizer(field_number, is_repeated, is_packed)
    local tag_size = _TagSize(field_number)
    local VarintSize = _VarintSize
    assert(not is_packed)
    if is_repeated then
        return function (value)
            local result = tag_size * #value
            for _,element in ipairs(value) do
                local l = #element
                result = result + VarintSize(l) + l
            end
            return result
        end
    else
        return function (value)
            local l = #value
            return tag_size + VarintSize(l) + l
        end
    end
end

function _M.MessageSizer(field_number, is_repeated, is_packed)
    local tag_size = _TagSize(field_number)
    local VarintSize = _VarintSize
    assert(not is_packed)
    if is_repeated then
        return function(value)
            local result = tag_size * #value
            for _,element in ipairs(value) do
                local l = element:ByteSize()
                result = result + VarintSize(l) + l
            end
            return result
        end
    else
        return function (value)
            local l = value:ByteSize()
            return tag_size + VarintSize(l) + l
        end
    end
end


-- ====================================================================
--  Encoders!

local _EncodeVarint = pb.varint_encoder
local _EncodeSignedVarint = pb.signed_varint_encoder


local function _VarintBytes(value)
    local out = {}
    local write = function(value)
        out[#out + 1 ] = value
    end
    _EncodeSignedVarint(write, value)
    return table.concat(out)
end

function _M.TagBytes(field_number, wire_type)
  return _VarintBytes(wire_format.PackTag(field_number, wire_type))
end

local function _SimpleEncoder(wire_type, encode_value, compute_value_size)
    return function(field_number, is_repeated, is_packed)
        if is_packed then
            local tag_bytes = _M.TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
            local EncodeVarint = _EncodeVarint
            return function(write, value)
                write(tag_bytes)
                local size = 0
                for _, element in ipairs(value) do
                    size = size + compute_value_size(element)
                end
                EncodeVarint(write, size)
                for element in value do
                    encode_value(write, element)
                end
            end
        elseif is_repeated then
            local tag_bytes = _M.TagBytes(field_number, wire_type)
            return function(write, value)
                for _, element in ipairs(value) do
                    write(tag_bytes)
                    encode_value(write, element)
                end
            end
        else
            local tag_bytes = _M.TagBytes(field_number, wire_type)
            return function(write, value)
                write(tag_bytes)
                encode_value(write, value)
            end
        end
    end
end

local function _ModifiedEncoder(wire_type, encode_value, compute_value_size, modify_value)
    return function (field_number, is_repeated, is_packed)
        if is_packed then
            local tag_bytes = _M.TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
            local EncodeVarint = _EncodeVarint
            return function (write, value)
                write(tag_bytes)
                local size = 0
                for _, element in ipairs(value) do
                    size = size + compute_value_size(modify_value(element))
                end
                EncodeVarint(write, size)
                for _, element in ipairs(value) do
                    encode_value(write, modify_value(element))
                end
            end
        elseif is_repeated then
            local tag_bytes = _M.TagBytes(field_number, wire_type)
            return function (write, value)
                for _, element in ipairs(value) do
                    write(tag_bytes)
                    encode_value(write, modify_value(element))
                end
            end
        else
            local tag_bytes = _M.TagBytes(field_number, wire_type)
            return function (write, value)
                write(tag_bytes)
                encode_value(write, modify_value(value))
            end
        end
    end
end

local function _StructPackEncoder(wire_type, value_size, format)
    return function(field_number, is_repeated, is_packed)
        local struct_pack = pb.struct_pack
        if is_packed then
            local tag_bytes = _M.TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
            local EncodeVarint = _EncodeVarint
            return function (write, value)
                write(tag_bytes)
                EncodeVarint(write, #value * value_size)
                for _, element in ipairs(value) do
                    struct_pack(write, format, element)
                end
            end
        elseif is_repeated then
            local tag_bytes = _M.TagBytes(field_number, wire_type)
            return function (write, value)
                for _, element in ipairs(value) do
                    write(tag_bytes)
                    struct_pack(write, format, element)
                end
            end
        else
            local tag_bytes = _M.TagBytes(field_number, wire_type)
            return function (write, value)
                write(tag_bytes)
                struct_pack(write, format, value)
            end
        end

    end
end

_M.Int32Encoder = _SimpleEncoder(wire_format.WIRETYPE_VARINT, _EncodeSignedVarint, _SignedVarintSize)
_M.Int64Encoder = _M.Int32Encoder
_M.EnumEncoder = _M.Int32Encoder

_M.UInt32Encoder = _SimpleEncoder(wire_format.WIRETYPE_VARINT, _EncodeVarint, _VarintSize)
_M.UInt64Encoder = _M.UInt32Encoder

_M.SInt32Encoder = _ModifiedEncoder(
    wire_format.WIRETYPE_VARINT, _EncodeVarint, _VarintSize,
    wire_format.ZigZagEncode32)

_M.SInt64Encoder = _ModifiedEncoder(
    wire_format.WIRETYPE_VARINT, _EncodeVarint, _VarintSize,
    wire_format.ZigZagEncode64)

_M.Fixed32Encoder  = _StructPackEncoder(wire_format.WIRETYPE_FIXED32, 4, string.byte('I'))
_M.Fixed64Encoder  = _StructPackEncoder(wire_format.WIRETYPE_FIXED64, 8, string.byte('Q'))
_M.SFixed32Encoder = _StructPackEncoder(wire_format.WIRETYPE_FIXED32, 4, string.byte('i'))
_M.SFixed64Encoder = _StructPackEncoder(wire_format.WIRETYPE_FIXED64, 8, string.byte('q'))
_M.FloatEncoder    = _StructPackEncoder(wire_format.WIRETYPE_FIXED32, 4, string.byte('f'))
_M.DoubleEncoder   = _StructPackEncoder(wire_format.WIRETYPE_FIXED64, 8, string.byte('d'))


function _M.BoolEncoder(field_number, is_repeated, is_packed)
    local false_byte = '\0'
    local true_byte = '\1'
    if is_packed then
        local tag_bytes = _M.TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
        local EncodeVarint = _EncodeVarint
        return function (write, value)
            write(tag_bytes)
            EncodeVarint(write, #value)
            for _, element in ipairs(value) do
                if element then
                    write(true_byte)
                else
                    write(false_byte)
                end
            end
        end
    elseif is_repeated then
        local tag_bytes = _M.TagBytes(field_number, wire_format.WIRETYPE_VARINT)
        return function(write, value)
            for _, element in ipairs(value) do
                write(tag_bytes)
                if element then
                    write(true_byte)
                else
                    write(false_byte)
                end
            end
        end
    else
        local tag_bytes = _M.TagBytes(field_number, wire_format.WIRETYPE_VARINT)
        return function (write, value)
            write(tag_bytes)
            if value then
                return write(true_byte)
            end
            return write(false_byte)
        end
    end
end

function _M.StringEncoder(field_number, is_repeated, is_packed)
    local tag = _M.TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
    local EncodeVarint = _EncodeVarint
    assert(not is_packed)
    if is_repeated then
        return function (write, value)
            for _, element in ipairs(value) do
--                encoded = element.encode('utf-8')
                write(tag)
                EncodeVarint(write, #element)
                write(element)
            end
        end
    else
        return function (write, value)
--            local encoded = value.encode('utf-8')
            write(tag)
            EncodeVarint(write, #value)
            return write(value)
        end
    end
end

function _M.BytesEncoder(field_number, is_repeated, is_packed)
    local tag = _M.TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
    local EncodeVarint = _EncodeVarint
    assert(not is_packed)
    if is_repeated then
        return function (write, value)
            for _, element in ipairs(value) do
                write(tag)
                EncodeVarint(write, #element)
                write(element)
            end
        end
    else
        return function(write, value)
            write(tag)
            EncodeVarint(write, #value)
            return write(value)
        end
    end
end


function _M.MessageEncoder(field_number, is_repeated, is_packed)
    local tag = _M.TagBytes(field_number, wire_format.WIRETYPE_LENGTH_DELIMITED)
    local EncodeVarint = _EncodeVarint
    assert(not is_packed)
    if is_repeated then
        return function(write, value)
            for _, element in ipairs(value) do
                write(tag)
                EncodeVarint(write, element:ByteSize())
                element:_InternalSerialize(write)
            end
        end
    else
        return function (write, value)
            write(tag)
            EncodeVarint(write, value:ByteSize())
            return value:_InternalSerialize(write)
        end
    end
end

return _M

