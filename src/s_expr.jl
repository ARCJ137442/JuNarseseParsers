#=
S-表达式 转换
- 基于AST的原理
- 自制字符串解析器
- 便于Lisp系语言解析
=#

# 导出

export SExprParser
export SExprParser_pure, SExprParser_optimized


"转换的两种形式：纯字串/字串-数组"
const SExpr_VTypes::Type = Union{
    Any, # 允许不使用引号的字符串
    String, # 所有字符串都需转义
}

"""
基于原生数组（向量）的S-表达式（字串）互转方法

初步实现方式：
- SExpr↔向量↔Narsese对象

S-表达式举例:
(Word A)
(Inheritance (Word A) (Word B))
(SentenceJudgement (Truth64 1.0 0.5) (StampBasic ...))
"""
abstract type SExprParser{Variant <: Conversion.Native_VTypes} <: AbstractParser end

"转换器の类型"
const TSExprParser::Type = Type{<:SExprParser}

# 别名
const SExprParser_pure::TSExprParser = SExprParser{Dict}
const SExprParser_optimized::TSExprParser = SExprParser{Vector}

# 重载「字符串宏の快捷方式」
@register_parser_string_flag [
    :s => SExprParser_optimized
    :s_o => SExprParser_optimized
    :s_optimized => SExprParser_optimized
    
    :s_pure => SExprParser_pure
    :s_p => SExprParser_pure
]

"""
定义「SExpr转换」的「目标类型」
- SExpr字串↔Narsese对象
"""
const SExpr_PARSE_TARGETS::Type = Conversion.DEFAULT_PARSE_TARGETS

"目标类型：Narsese对象"
Conversion.parse_target_types(::TSExprParser) = SExpr_PARSE_TARGETS

"数据类型：以SExpr表示的字符串"
Base.eltype(::TSExprParser)::Type = String

begin "基础方法集"

    """
    字符串 → S-表达式の值
    - 若其中含有空白符，需要使用引号转义
        - 示例：`123 123` --> `"123 123"`
        - 转义：使用`Base.repr`方法
        - 逆转义：使用`Meta.parse`方法（不执行代码）
    """
    s_expr(str::AbstractString; always_escape::Bool=false)::AbstractString = (
        always_escape || any(isspace, str) ?
            Base.repr(str) : # 需要转义
            str # 无需转义
    )
    
    """
    原生数组→S-表达式

    示例：
        `["A", "sp ace", ["2", "3"], "B"]` --> `(A "sp ace" (2 3) B)`
    """
    s_expr(obj::Vector; always_escape::Bool=false)::String = '(' * join(s_expr.(obj; always_escape), ' ') * ')'

    "开/闭括弧 + 引号"
    const S_EXPR_OPEN_BRACKET::Char = '('
    const S_EXPR_CLOSE_BRACKET::Char = ')'
    const S_EXPR_QUOTE::Char = '"'

    """
    S-表达式 → 数组（主入口）
    - 参数集：
        - str：被解析的字符串整体
        - start：解析的开始位置
            - 决定会在解析到何时停止（与start位置同级的下一个闭括弧）
            - 用于递归解析

    示例：`(A (B C D) E "spa ce")` --> `["A", ["B", "C", "D"], "E", "spa ce"]`
    """
    parse_s_expr(str::AbstractString)::Vector = _parse_s_expr(str)[1] # [1]是「最终结果」

    """
    内部的解析逻辑：
    - 返回: (值, 原字串str上解析的最后一个索引)
    """
    function _parse_s_expr(s::AbstractString, start::Integer = 1; end_i = lastindex(s))::Tuple{Vector, Int}
        # 判断首括弧
        s[start] == S_EXPR_OPEN_BRACKET || throw(ArgumentError("S-表达式必须以『(』为起始字符：$s"))
        
        local result::Vector{Union{Vector,String}} = Union{Vector,String}[]
        local i::Int = start
        local si::Char
        local next_index::Int

        while true
            # 先步进，跳过start处的开括弧
            i = nextind(s, i)

            # nextind在lastindex时也会正常工作，但此时返回的新索引会跳转到
            i > end_i && error("无效的S-表达式「$s」$result")

            # 获取当前字符
            si = s[i]

            # 中途遇到字串外开括弧：递归解析下一层，并将返回值添加进「内容」vals
            if si == S_EXPR_OPEN_BRACKET
                # 递归解析
                vec::Vector, i_sub_end = _parse_s_expr(s, i; end_i = end_i) # 复用end_i变量
                # 添加值
                push!(result, vec)
                # 跳过已解析处，步进交给前面
                i = i_sub_end
            # 中途遇到字串外闭括弧（一定是同级闭括弧）：结束解析，返回值
            elseif si == S_EXPR_CLOSE_BRACKET
                return result, i # 闭括弧所在处
            # 非空白、非括弧字符：解析字符串值
            elseif !isspace(si)
                # 递归解析
                str::String, i_sub_end = (
                    si == S_EXPR_QUOTE ? # 是否要转义？
                        _parse_escaped_s_expr_string(s, i; end_i = end_i) : # 复用end_i变量
                        _parse_s_expr_string(s, i; end_i = end_i) # 复用end_i变量
                )
                # 添加值
                push!(result, str)
                # 跳过已解析处
                i = i_sub_end
            end
            # 空白符⇒跳过
        end
    end

    """
    特殊：解析S-表达式中的原子值（字符串）
    - 未转义：开头无引号
    - 已转义：开头有引号(另外实现)
    - ⚠只关注「是否有空格/是否遇到未转义引号」，不检测括弧

    返回值：
    - 解析好的字符串值（需要转义的也已经转义）
    - 解析好

    示例：
    `A123` --> "A123"
    `"spac e()"` --> "spac e()"
    """
    function _parse_s_expr_string(s::AbstractString, start::Integer = 1; end_i = lastindex(s))::Tuple{String, Int}
        # 初始化
        local start_i::Int = start # 用于字符串截取
        local i::Int = start
        local si::Char = s[i] # 当前字符

        # 一路识别到第一个空白字符/闭括弧（不允许「f(x)」这样的紧凑格式）
        while !isspace(si) && si != S_EXPR_CLOSE_BRACKET
            i = nextind(s, i) # 直接步进
            i > end_i && error("无效的S-表达式「$s」")
            si = s[i] # 更新si
        end # 循环退出时，s[i]已为空白符

        # 返回字串
        return s[start_i:prevind(s, i)], prevind(s, i) # 最后一个非空白字符处
    end

    """
    解析「需要转义的字符串」
    """
    function _parse_escaped_s_expr_string(s::AbstractString, start::Integer = 1; end_i = lastindex(s))::Tuple{String, Int}
        # 初始化
        local last_si::Char = s[start]

        local start_i::Int = nextind(s, start) # 用于字符串截取
        local i::Int = start_i
        i > end_i && error("无效的S-表达式「$s」")

        # 跳转到下一个非「\"」的「"」
        while true
            si = s[i]
            # 终止条件：非转义引号
            if si == S_EXPR_QUOTE && last_si != '\\'
                # 返回逆转义后的字符串(截取包括引号)
                return Meta.parse(@view s[start:i]), i
            end
            # 步进
            last_si = s[i]
            i = nextind(s, i)
            i > end_i && error("无效的S-表达式「$s」")
            si = s[i]
        end
    end

end

begin "具体转换实现"
    
    "SExpr字符串⇒表达式⇒Narsese对象"
    function data2narsese(parser::TSExprParser, ::Type, s_expr::String)::SExpr_PARSE_TARGETS
        return data2narsese(
            NativeParser_vector,
            Any, # 兼容模式
            parse_s_expr(s_expr)
        )
    end
    
    "Narsese对象⇒表达式⇒SExpr字符串"
    function narsese2data(parser::TSExprParser, t::SExpr_PARSE_TARGETS)::String
        return s_expr(
            narsese2data(NativeParser_vector, t);
            always_escape = parser == SExprParser_pure # 纯粹模式⇒总是转义
        )
    end

end
