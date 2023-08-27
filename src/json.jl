#=
JSON转换
- 基于Julia原生对象
=#

# 导入

import JSON

# 导出

export JSONParser
export JSONParser_object, JSONParser_array

"""
基于AST的JSON互转方法

初步实现方式：
- JSON↔object↔AST↔Narsese对象

JSON转换的两种形式

1. 字典形式
    ```
    {
        "Word": ["词项"]
    }
    {
        "ExtDifference": [
            {
                "Operator": "操作"
            },
            {
                "IVar": "独立变量"
            }
        ]
    }
    ```
2. 数组形式
    ```
    [
        "Word",
        "词项"
    ]
    [ # 反正head只有一个
        "ExtDifference",
        [
            "Operator", "操作"
        ]
        [
            "IVar", "独立变量"
        ]
    ]
    ```
"""
abstract type JSONParser{Variant <: Conversion.Native_VTypes} <: AbstractParser end

"转换器の类型"
const TJSONParser::Type = Type{<:JSONParser}

# 别名
const JSONParser_object::TJSONParser = JSONParser{Dict}
const JSONParser_array::TJSONParser = JSONParser{Vector}

"从JSON解析器到原生对象解析器"
const JSON_PARSER_DICT::Dict = Dict(
    JSONParser_object => NativeParser_dict,
    JSONParser_array => NativeParser_vector,
)

# 重载「字符串宏の快捷方式」
@register_parser_string_flag [
    :json => JSONParser
    :json_array => JSONParser_array
    :json_object => JSONParser_object
]

"""
定义「JSON转换」的「目标类型」
- JSON字串↔Narsese对象
"""
const JSON_PARSE_TARGETS::Type = Conversion.DEFAULT_PARSE_TARGETS

"目标类型：Narsese对象"
Conversion.parse_target_types(::TJSONParser) = JSON_PARSE_TARGETS

"数据类型：以JSON表示的字符串"
Base.eltype(::TJSONParser)::Type = String

begin "具体转换实现"
    
    "JSON字符串⇒原生对象⇒Narsese对象"
    function data2narsese(parser::TJSONParser, ::Type, json::String)::JSON_PARSE_TARGETS
        obj = JSON.parse(json)
        return data2narsese(JSON_PARSER_DICT[parser], Any, obj)
    end
    
    "Narsese对象⇒原生对象⇒JSON字符串"
    function narsese2data(parser::TJSONParser, t::JSON_PARSE_TARGETS)::String
        obj = narsese2data(JSON_PARSER_DICT[parser], t)
        return JSON.json(obj)
    end

end
