# 导入
import Serialization

# 导出
export S11nParser

"""
提供字节流(序列化/反序列化)处理方法
- 封装转换时的IO，仅提供转换后的字节串
- ⚠尚不稳定：读取可能会出错
"""
abstract type SerializationParser <: AbstractParser end
const S11nParser::Type = SerializationParser # 短别名

const Bytes8::DataType = Vector{UInt8}

"类型の短别名"
const TSParser::Type = Type{S11nParser}

"目标类型：Narsese对象"
const S11N_PARSE_TARGETS::Type = Conversion.DEFAULT_PARSE_TARGETS
Conversion.parse_target_types(::TSParser) = S11N_PARSE_TARGETS

"数据类型：字节流对象 Vector{UInt8}"
Base.eltype(::TSParser)::Type = Bytes8

# 正式开始 #

# 具体Narsese对接

"""
总「解析」方法：任意对象都可序列化
- 任意类型都适用
"""
function data2narsese(::TSParser, ::Type, bytes::Bytes8)::S11N_PARSE_TARGETS
    Serialization.deserialize(
        IOBuffer(bytes)
    )
end

"""
所有Narsese对象的序列化方法
"""
function narsese2data(::TSParser, t::S11N_PARSE_TARGETS)::Bytes8
    b::IOBuffer = IOBuffer()
    Serialization.serialize(b, t)
    return b.data::Bytes8 # 断言其必须是Bytes8
end
