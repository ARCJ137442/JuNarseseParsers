#=
JSON转换
- 基于AST的原理
=#

# 导入

import JSON

# 导出

export JSONParser
export JSONParser_object, JSONParser_array

"""
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
const JSON_VTypes::Type = Union{Vector}

"""
基于AST的JSON互转方法

初步实现方式：
- JSON↔object↔AST↔词项
"""
abstract type JSONParser{Variant <: JSON_VTypes} <: AbstractParser end

"转换器の类型"
const TJSONParser::Type = Type{<:JSONParser}

# 别名
const JSONParser_object::TJSONParser = JSONParser # 默认采用object格式
const JSONParser_array::TJSONParser = JSONParser{Vector}

"重载「字符串宏の快捷方式」:json"
Conversion.get_parser_from_flag(::Val{:json})::TAbstractParser = JSONParser

"重载「字符串宏の快捷方式」:json_array"
Conversion.get_parser_from_flag(::Val{:json_array})::TAbstractParser = JSONParser_array

"重载「字符串宏の快捷方式」:json_object"
Conversion.get_parser_from_flag(::Val{:json_object})::TAbstractParser = JSONParser_object

"""
定义「JSON转换」的「目标类型」
- JSON字串↔词项/语句
"""
const JSON_PARSE_TARGETS::Type = Conversion.DEFAULT_PARSE_TARGETS

"目标类型：词项/语句"
Conversion.parse_target_types(::TJSONParser) = JSON_PARSE_TARGETS

"数据类型：以JSON表示的字符串"
Base.eltype(::TJSONParser)::Type = String

begin "基础方法集"

    "默认方法：用于递归处理参数（无需类型判断，只需使用多分派）"
    function _preprocess(::Type{T}, val::Any) where T
        val # 数字/字符串
    end
    
    "预处理：表达式⇒字典"
    _preprocess(parser::Type{JSONParser_object}, ast::Expr)::Dict = Dict(
        string(ast.head) => _preprocess.(parser, ast.args) # 批量处理
    )

    "预处理：表达式⇒数组（向量）"
    _preprocess(parser::Type{JSONParser_array}, ast::Expr)::Vector = [
        string(ast.head), # 头
        _preprocess.(parser, ast.args)... # 批量处理并展开
    ]

    "默认方法：用于递归处理参数（无需类型判断，只需使用多分派）"
    _preparse(::Type, v::Any) = v # 数字/字符串

    "预解析：字典⇒表达式"
    _preparse(parser::Type{JSONParser_object}, d::Dict)::Expr = begin
        pair::Pair = collect(d)[1]
        return Expr(
            Symbol(pair.first), # 只取第一个键当类名
            _preparse.(parser, pair.second)..., # 只取第一个值当做参数集
        )
    end

    "预解析：数组（向量）⇒表达式"
    _preparse(parser::Type{JSONParser_array}, v::Vector)::Expr = Expr(
        Symbol(v[1]), # 取第一个当类名
        _preparse.(parser, v[2:end])..., # 其后当做参数
    )
end

begin "具体转换实现"
    
    "JSON字符串⇒表达式⇒词项"
    function data2narsese(parser::TJSONParser, ::Type, json::String)::JSON_PARSE_TARGETS
        obj = JSON.parse(json)
        expr::Expr = _preparse(parser, obj)
        return data2narsese(ASTParser, Any, expr)
    end
    
    "词项⇒表达式⇒JSON字符串"
    function narsese2data(parser::TJSONParser, t::JSON_PARSE_TARGETS)::String
        expr::Expr = narsese2data(ASTParser, t)
        obj = _preprocess(parser, expr)
        return JSON.json(obj)
    end

end
