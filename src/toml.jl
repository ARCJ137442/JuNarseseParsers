#=
TOML 转换
- 基于Julia「原生对象」解析器
- 使用外部`TOML.jl`库

【20230824 20:31:40】目前TOML不支持与数组的互转（至少最外层不能是数组）
=#

# 导入
using TOML

# 导出

export TOMLParser

"""
基于AST的TOML（字串）互转方法

初步实现方式：
- TOML↔AST↔Narsese对象

TOML举例:
[[Word]]
A

[[SentenceJudgement]]
Truth64 = ...
StampBasic = ...

"""
abstract type TOMLParser <: AbstractParser end

"转换器の类型"
const TTOMLParser::Type = Type{<:TOMLParser}

# 重载「字符串宏の快捷方式」
@register_parser_string_flag [
    :toml => TOMLParser
]

"""
定义「TOML转换」的「目标类型」
- TOML字串↔Narsese对象
"""
const TOML_PARSE_TARGETS::Type = Conversion.DEFAULT_PARSE_TARGETS

"目标类型：Narsese对象"
Conversion.parse_target_types(::TTOMLParser) = TOML_PARSE_TARGETS

"数据类型：以TOML表示的字符串"
Base.eltype(::TTOMLParser)::Type = String

# 正式开始 #

# 总体IO缓冲区（可复用）
const TOML_GLOBAL_BUFFER::IOBuffer = IOBuffer()

begin "具体转换实现"
    
    "TOML字符串⇒表达式⇒Narsese对象"
    function data2narsese(parser::TTOMLParser, ::Type, toml::String)::TOML_PARSE_TARGETS
        obj = TOML.parse(toml)
        return data2narsese(
            NativeParser_dict, Any, 
            obj
        )
    end
    
    "Narsese对象⇒表达式⇒TOML字符串"
    function narsese2data(parser::TTOMLParser, t::TOML_PARSE_TARGETS)::String
        obj = narsese2data(NativeParser_dict, t)
        TOML.print(TOML_GLOBAL_BUFFER, obj) # 将TOML数据输出到缓冲区
        return String(
            take!(TOML_GLOBAL_BUFFER) # 从缓冲区中取出所有数据，并清空缓冲区
        )
    end

end
