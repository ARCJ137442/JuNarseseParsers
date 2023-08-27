#=
YAML 转换
- 基于AST的原理
- 使用外部`YAML.jl`库
=#

# 导入
import YAML

# 导出

export YAMLParser
export YAMLParser_dict, YAMLParser_vector

"转换的两种形式：字典/数组"
const YAML_VTypes::Type = Union{
    Dict,
    Vector,
}

"""
基于AST的YAML（字串）互转方法

初步实现方式：
- YAML↔AST↔词项

YAML举例:
Word:
- A

SentenceJudgement
- Truth64: [1.0, 0.5]
- StampBasic: ...

"""
abstract type YAMLParser{Variant <: Conversion.Native_VTypes} <: AbstractParser end

"转换器の类型"
const TYAMLParser::Type = Type{<:YAMLParser}

# 别名
const YAMLParser_dict::TYAMLParser = YAMLParser{Dict}
const YAMLParser_vector::TYAMLParser = YAMLParser{Vector}

"从YAML解析器到原生对象解析器"
const YAML_PARSER_DICT::Dict = Dict(
    YAMLParser_dict => NativeParser_dict,
    YAMLParser_vector => NativeParser_vector,
)

# 重载「字符串宏の快捷方式」
@register_parser_string_flag [
    :yaml => YAMLParser
    :yml  => YAMLParser
]

"""
定义「YAML转换」的「目标类型」
- YAML字串↔Narsese对象
"""
const YAML_PARSE_TARGETS::Type = Conversion.DEFAULT_PARSE_TARGETS

"目标类型：Narsese对象"
Conversion.parse_target_types(::TYAMLParser) = YAML_PARSE_TARGETS

"数据类型：以YAML表示的字符串"
Base.eltype(::TYAMLParser)::Type = String

begin "具体转换实现"
    
    "YAML字符串⇒表达式⇒词项"
    function data2narsese(parser::TYAMLParser, ::Type, yaml::String)::YAML_PARSE_TARGETS
        obj = YAML.load(yaml)
        return data2narsese(YAML_PARSER_DICT[parser], Any, obj)
    end
    
    "词项⇒表达式⇒YAML字符串"
    function narsese2data(parser::TYAMLParser, t::YAML_PARSE_TARGETS)::String
       
        obj = narsese2data(YAML_PARSER_DICT[parser], t)
        return YAML.write(obj)
    end

end
