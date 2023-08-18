#=
XML转换
- 基于AST的原理
=#

# 导入

import XML

# 导出

export XMLParser, XMLParser_optimized, XMLParser_pure

"""
提供XML互转方法

## 初步实现方式
- 词项↔AST↔XML
- 📄解析后XML内只有：
    - String(位于「文本」类型的XML.Node)
        - 这意味着Number、Symbol类型需先从String中解析
            - Number => parse(类型, 字符串值)
                - 照应AST中的`数字 => Expr(:类型, 值)（视作「结构类型」）`
            - Symbol => Symbol(字符串值)
                - 非保留特征头⇒类名
    - 其它XML.Node

## 「基于AST解析器+附带优化」的一般逻辑

核心：半「AST机翻」半「自行润色」
0. 可扩展性：
    - 区分「AST方法」与「私有方法」
    - 使用ASTの递归回调机制，回调指向「私有方法」实现「内层预润色」
1. 解析の逻辑（XML：XML.Node⇒目标对象）
    - 参数集：解析器，被解析对象（XML.Node）
        - 「eval函数」「递归回调函数」均由「私有解析方法」决定
        - 其它参数用法同AST
    - 若有「特别解析通道」：（XML：纯翻译模式不走此路）
        - 协议：特别解析函数(解析器, 识别出的类型, 被解析对象)
        1. 通过「特别方式」直接组装成Expr
            - （XML）原生类型String：节点类型==XML.Text
                - 返回value
        2. 用AST解析Expr，其中回调「解析函数」（XML：`recurse_callback=xml_parse`）
            - 此举相当于「先回调解析，再AST解析单层Expr」
    - 默认：
        1. 拆分XML，得到「数据对象」+未解析参数集（可能中途返回）
            - （XML）ASTの结构类型：自动消转义（或根据类分派「特别方式」）
                1. 类名::String = 标签==结构转义标签 ? 取type属性 : 标签
                2. 类::Type = AST解析类名
                3. 分派「特别方式」：调用「特别解析函数」
                    - 用于「带优化模式」中词项、语句的优化
                    - 同时存在
                4. 若无分派（返回「被解析对象」自身）：获取头
                    - 头::Symbol = Symbol(类名)
            - （XML）ASTの保留类型：标签==保留类标签
                - 头::Symbol = Symbol(取head属性)
            - （XML）[新] 数值类型：标签==数值类标签
                1. 读取「类型」「字符串值」属性
                2. 调用「字符串⇒数值」方法：`Base.parse(type, value)`
                3. 直接返回解析后的数值
                - 例：`<Number type="Int8" value="127"/>` => `Base.parse(Int8, "127")` => `127::Int8`
        2. 将「未解析参数集」作为args，组装出Expr（XML：子节点children）
        3. 用AST解析Expr(头, args)，其中回调「解析函数」（XML：`recurse_callback=xml_parse`）
            - 相当于「先拆分XML，再逐一转换参数集，最后用AST解析单层」
2. 打包の逻辑（XML：目标对象⇒XML.Node）
    - 参数集：解析器，被打包对象
        - 「eval函数」「递归回调函数」均由「私有打包方法」决定
        - 其它参数用法同AST
    - 若走「特别打包通道」：（XML：纯翻译模式不走此路）
        - 实现方法：「被打包对象」的类型派发
        - 对其内所有参数回调「打包函数」
        - 通过「特别方式」直接组装成数据对象（XML）
            - （XML）例：
                - 字符串：返回「纯文本」`XML.Node(字符串)`
                - 数值：返回「数值类型」
                    - `127::Int8` => `<Number type="Int8" value="127"/>`
    - 默认：
        1. 用AST打包一层得Expr，其中回调「解析函数」（XML：`recurse_callback=xml_parse`）
            - 或：翻译一层对「待解析参数集」回调「打包函数」
        2. 拆分Expr，得到「数据对象」（XML）+已解析参数集（Any）
            - （XML）ASTの结构类型：根据类名决定是否转义
                - 转义：<结构转义标签 type="类名">...
            - （XML）ASTの保留类型：<保留类标签 head="表达式头">
            - （XML）ASTの原生类型：会被「特别打包通道」分派
                - 字符串
                - 数值
        3. 组装成分，得到完整的「数据对象」（XML）

    
## 已知问题

### 对节点标签带特殊符号的XML解析不良

例1：前导冒号丢失——影响「保留特征头」
```
julia> s1 = XML.Node(XML.Element,":a:", 1,1,1) |> XML.write
"<:a: 1=\"1\">1</:a:>"

julia> XML.parse(s1, Node) |> XML.write
"<a:>1</a:>\n"
```

例2：带花括号文本异位——影响「结构类型の解析」
```
julia> n = XML.Node(XML.Element,"a{b}", (type="Vector{Int}",),1,1)
Node Element <a{b} type="Vector{Int}"> (1 child)

julia> XML.write(n)
"<a{b} type=\"Vector{Int}\">1</a{b}>"

julia> XML.parse(XML.write(n),Node)[1]
Node Element <a b="Vector{Int}"> (1 child)
```

### 对单自闭节点解析失败

例：
```
julia> s1 = XML.Node(XML.Element,"a") |> XML.write
"<a/>"

julia> XML.parse(s1, Node) |> XML.write
ERROR: MethodError: no method matching isless(::Int64, ::Nothing)

Closest candidates are:
  isless(::Real, ::AbstractFloat)
   @ Base operators.jl:178
  isless(::Real, ::Real)
   @ Base operators.jl:421
  isless(::Any, ::Missing)
   @ Base missing.jl:88
  ...
```

## 例
源Narsese：
`<(|, A, ?B) --> (/, A, _, ^C)>. :|: %1.0;0.5%`

AST:
```
:SentenceJudgement
    :Inheriance,
        :IntIntersection,
            :Word,
                "A" # 字符串与符号通用
            :QVar,
                "B"
        :ExtImage,
            2,
            :Word,
                "A"
            :Operator,
                "C"
    :Truth
        1.0
        0.5
    :StampBasic{Present}
        【保留特征头】
            :vect
        :Int
            0
        :Int
            0
        :Int
            0
```

纯翻译模式`XMLParser{Expr}`
```
<SentenceJudgement>
    <Inheriance>
        <IntIntersection>
            <Word><Symbol>A</Symbol></Word>
            <QVar><Symbol>B</Symbol></QVar>
        </IntIntersection>
        <ExtImage>
            <Int>1<Int>
            <Word><Symbol>A</Symbol></Word>
            <Operator><Symbol>C</Symbol></Operator>
        </ExtImage>
    </Inheriance>
    <Truth16>
        <Float16>1.0<Float16>
        <Float16>0.5<Float16>
    </Truth16>
    <结构转义标签 type="StampBasic{Present}">
        <保留类标签 head="vect"/>
        <Int>0<Int>
        <Int>0<Int>
        <Int>0<Int>
    </结构转义标签>
</SentenceJudgement>
```

带优化模式`XMLParser`
```
<SentenceJudgement>
    <Inheriance>
        <IntIntersection>
            <Word name="A"/>
            <QVar name="B"/>
        </IntIntersection>
        <ExtImage relation_index="1">
            <Word name="A"/>
            <Operator name="C"/>
        </ExtImage>
    </Inheriance>
    <Truth16 f="1.0", c="0.5"/>
    <StampBasic tense="Present">
        <保留类标签 head="vect"/>
        <Int value="0">
        <Int value="0">
        <Int value="0">
    </StampBasic>
</SentenceJudgement>
```
"""
abstract type XMLParser{Varient} <: AbstractParser end

"类型の短别名"
const TXMLParser::Type = Type{<:XMLParser} # 泛型の不变性の要求

# 声明各个「子模式」：纯翻译、带优化 #

"带优化：尽可能地利用XML的数据结构，使打包的代码更简洁"
const XMLParser_optimized::Type = XMLParser # 不带参数类

"纯翻译：纯粹地将AST直译成XML"
const XMLParser_pure::Type = XMLParser{Dict} # 带参数类Dict

"重载「字符串宏の快捷方式」:xml"
Conversion.get_parser_from_flag(::Val{:xml})::TAbstractParser = XMLParser

"重载「字符串宏の快捷方式」:xml_optimized"
Conversion.get_parser_from_flag(::Val{:xml_optimized})::TAbstractParser = XMLParser_optimized

"重载「字符串宏の快捷方式」:xml_puret"
Conversion.get_parser_from_flag(::Val{:xml_pure})::TAbstractParser = XMLParser_pure

const TXMLParser_optimized::Type = Type{XMLParser_optimized} # 仅一个Type
const TXMLParser_pure::Type = Type{XMLParser_pure}

"""
声明「目标类型」
- 能被解析器支持解析
"""
const XML_PARSE_TARGETS::Type = DEFAULT_PARSE_TARGETS

"目标类型：词项/语句"
Conversion.parse_target_types(::TXMLParser) = XML_PARSE_TARGETS

"""
声明「原生类型」
- 解析器直接返回Node(自身)
"""
const XML_NATIVE_TYPES::Type = Union{
    String # 字符串
}

"""
声明用于「保留类型识别」的「保留类标签」
- ⚠已知问题：该「保留类标签」可能与AST中「保留特征头」不同
    - 前导冒号缺失：如`:a:` => `a:`
        - 【20230806 18:07:36】目前尚不影响
"""
const XML_PRESERVED_TAG::String = XML.parse(
    XML.Node(
        XML.Element,
        string(Conversion.AST_PRESERVED_HEAD), # 作为字串
        1,1,1 # 后面几个是占位符，避免「单自闭节点解析失败」的Bug
    ) |> XML.write,
    XML.Node
)[1].tag # `[1]`从Document到Element，`.tag`获取标签（字符串）

"""
声明「结构转义标签」
- 用于可能的「Vector{Int}」的转义情况
"""
const XML_ESCAPE_TAG::String = "XML_ESCAPE"

"""
用于判断「是否需要转义」的正则表达式
- 功能：判断一个「构造函数名」是否「符合XML节点标签」标准
- 逻辑：不符合标准⇒需要转义
"""
const XML_ESCAPE_REGEX::Regex = r"^\w+$"

"""
声明「数值类标签」
- 用于定义XML「字符串⇒数值」的「数值类」
"""
const XML_NUMBER_TAG::String = "Number"

"""
声明「数值类」（用于打包）
"""
const XML_NUMBER_TYPES::Type = Union{
    Number
}

"以XML表示的字符串"
Base.eltype(::TXMLParser)::Type = String

begin "解析の逻辑"

    """
    通用方法：获取一个标签内表示「类型」的字符串
    - 无转义：标签本身
    - 有转义：标签「type」属性
    """
    @inline parse_node_type_name(n::XML.Node, tag::String)::String = (
        tag == XML_ESCAPE_TAG ? 
        n.attributes["type"] : 
        tag
    )

    "自动获取标签"
    @inline parse_node_type_name(n::XML.Node)::String = parse_node_type_name(
        n, n.tag
    )

    """
    通用方法：用于从一个XML节点中提取数据类型（可以调用构造方法的）
    - 默认提取标签
    - 若有转义，提取「type」属性
    - 无论是否在「特别解析通道」都可调用"""
    @inline parse_node_type(n::XML.Node, eval_function::Function)::Type = parse_node_type(
        n, n.tag, eval_function
    )

    "加速在已有tag的情况下"
    @inline parse_node_type(n::XML.Node, tag::String, eval_function::Function)::Type = Conversion.parse_type(
        parse_node_type_name(n, tag),
        eval_function
    )

    """
    通用方法：从「结构类型」中构建XML（元素）节点
    - 用于确保「无论何时需要以『结构类型』封装对象，都可正确转义而非把特殊符号带进节点标签中」
    """
    function xml_form_struct(
        type_name::String,
        attributes::NamedTuple = NamedTuple(), # 默认是空的具名元组
        children::Union{Vector, Nothing} = nothing, # 可空
        )::XML.Node
        # 转义的条件：类名包含特殊符号
        isnothing(match(XML_ESCAPE_REGEX, type_name)) && return XML.Node(
            XML.Element,
            XML_ESCAPE_TAG,
            merge(attributes, (type=type_name,)), # 合并具名元组（注意：不能使用`...`展开式）
            nothing, # 无value
            children,
        )
        # 否则无需转义
        return XML.Node(
            XML.Element,
            type_name,
            attributes,
            nothing, # 无value
            children,
        )
    end

    "重载：适应「仅需children」的情况" # 仅name的情况留在上一个方法
    @inline xml_form_struct(type_name::String, children::Union{Vector, Nothing}) = xml_form_struct(type_name, NamedTuple(), children)

    """
    默认解析方法
    - 仅用于：
        - XML.Element
        - XML.Text
    """
    function xml_parse(
        parser::TXMLParser, n::XML.Node,
        eval_function = Narsese.eval
        )::Any
        # 原生类型：字符串
        if n.nodetype == XML.Text
            return n.value
        end
        
        local tag::String = n.tag
        local head::Symbol, args::Vector, type::Type, literal::String
        # 保留类型
        if tag == XML_PRESERVED_TAG
            head = Symbol(n.attributes["head"])
            args = n.children
        # 数值类型
        elseif tag == XML_NUMBER_TAG
            return xml_parse_special(parser, Number, n)
        # 结构类型
        else
            # 字符串⇒类型
            type = parse_node_type(n, tag, eval_function) # 可能解析出错
            # 尝试「特别解析」：取捷径解析对象
            parse_special::Any = xml_parse_special(
                parser, type, n
            )
            if parse_special isa XML.Node # 返回自身⇒继续
                head = Symbol(type) # 直接字符串化类型
                args = isnothing(n.children) ? [] : n.children
            else
                # 直接返回原对象
                return parse_special
            end
        end
        # 统一解析
        expr::Expr = Expr(head, args...)
        return Conversion.ast_parse(
            ASTParser, 
            expr,
            Narsese.eval,
            xml_parse,
            parser, # 递归回调解析器
        )
    end

    """
    （面向Debug）预打包@Symbol：xml将Symbol解析成构造函数
    """
    @inline xml_pack(parser::TXMLParser, s::Symbol)::XML.Node = xml_form_struct(
        "Symbol", 
        XML.Node[
            xml_pack(parser, string(s))
        ]
    )

    """
    默认预打包：任意对象⇒节点
    """
    function xml_pack(parser::TXMLParser, v::Any)::XML.Node
        # 先打包一层得「args全是Node的Expr」
        expr::Expr = Conversion.ast_pack(
            ASTParser, v, xml_pack,
            parser, # 递归回调解析器
        )

        # 保留类型：此时是Expr(保留特征头, 表达式头, 表达式参数...)
        expr.head == Conversion.AST_PRESERVED_HEAD && return XML.Node(
            XML.Element, # 类型：元素
            XML_PRESERVED_TAG, # 保留类标签
            (head=String(expr.args[1]),), # 获取第一个元素作「类名」（Symbol）
            nothing, # 无value
            expr.args[2:end], # 从第二个开始
        )
        # 结构类型：此时是Expr(:类名, 表达式参数...)
        return xml_form_struct(
            string(expr.head), # Symbol→string
            expr.args, # 表达式参数
        )
    end

    """
    默认「特别解析」：返回节点自身
    - 亦针对「原生类型」
    """
    @inline xml_parse_special(::TXMLParser, ::Type, n::XML.Node)::XML.Node = n

    """
    预打包：原生类型⇒XML节点：
    - 用于处理可以直接转换的原始类型数据
    - 最终会变成字符串
    """
    @inline xml_pack(::TXMLParser, val::XML_NATIVE_TYPES)::XML.Node = XML.Node(val)

    """
    特别解析@数值：节点⇒数值

    【20230819 0:21:52】有可能是某个地方的常量，比如「STAMP_TIME_TYPE」（JuNarsese.Narsese.Sentences.STAMP_TIME_TYPE）
    """
    @inline xml_parse_special(::TXMLParser, ::Type{Number}, n::XML.Node) = Base.parse(
        Conversion.parse_type(n.attributes["type"], Narsese.eval), 
        n.attributes["value"]
    )

    """
    预打包：数值类型⇒XML节点：
    - 任何XML解析器都支持解析
    - 用于处理可以直接转换的原始类型数据
    - 最终会变成字符串

    【20230806 20:32:37】已知问题：对带有Rational的数字类型，parse会产生解析错误
    """
    @inline xml_pack(::TXMLParser, num::Number)::XML.Node = XML.Node(
        XML.Element,
        XML_NUMBER_TAG, # 数值打包
        ( # 两个属性：类型&字符串值
            type=pack_type_string(num), # 类型
            value=string(num), # 数值
        ) # 后续属性空着不写
    )

    """
    特别解析@带优化：节点⇒原子词项
    """
    function xml_parse_special(::TXMLParser_optimized, ::Type{T}, n::XML.Node)::Term where {T <: Atom}
        type::DataType = parse_node_type(n, Narsese.eval) # 获得类型
        name::Symbol = n.attributes["name"] |> Symbol
        return type(name) # 构造原子词项
    end
    
    """
    预打包：原子词项⇒XML节点
    - 示例：`A` ⇒ `<Word name="A"/>`
    """
    xml_pack(::TXMLParser_optimized, t::Atom)::XML.Node = xml_form_struct(
        Conversion.pack_type_string(t), # 词项类型⇒元素标签
        (name=string(t.name),), # 属性：name=名称（字符串）
    )

    """
    特别解析@带优化：节点⇒陈述
    """
    function xml_parse_special(parser::TXMLParser_optimized, ::Type{<:Statement}, n::XML.Node)::Statement
        # @show n.tag
        type::DataType = parse_node_type(n, Narsese.eval) # 获得类型
        ϕ1::Term = xml_parse(parser, n[1])
        ϕ2::Term = xml_parse(parser, n[2])
        return type(ϕ1, ϕ2) # 构造原子词项
    end
    
    """
    预打包：陈述⇒XML节点
    - 示例：`<A --> B>` ⇒ ```
        <Implication>
            <Word name="A"/>
            <Word name="B"/>
        </Implication>
    ```
    """
    xml_pack(parser::TXMLParser_optimized, t::Statement)::XML.Node = xml_form_struct(
        Conversion.pack_type_string(t), # 词项类型⇒元素标签
        XML.Node[
            xml_pack(parser, t.ϕ1) # 第一个词项
            xml_pack(parser, t.ϕ2) # 第二个词项
        ]
    )

    """
    特别解析@带优化：节点⇒通用复合词项(像除外)
    """
    function xml_parse_special(parser::TXMLParser_optimized, ::Type{T}, n::XML.Node)::Term where {type <: ACompoundType, T <: ACompound{type}}
        constructor::DataType = parse_node_type(n, Narsese.eval) # 获得类型
        args = isnothing(n.children) ? [] : n.children # n.children可能是nothing
        terms::Vector = [
            xml_parse(parser, child)::Term
            for child::XML.Node in args
        ] # 广播
        return constructor(terms...) # 构造原子词项
    end
    
    """
    预打包：通用复合词项(像除外)
    - 特点：逐一打包其元素terms
    """
    @inline function xml_pack(parser::TXMLParser_optimized, t::ACompound{type})::XML.Node where {type <: AbstractCompoundType}
        return xml_form_struct(
            Conversion.pack_type_string(t), # 词项类型⇒元素标签
            [ # 子节点
                xml_pack(parser, term)::XML.Node
                for term::Term in t.terms # 统一预处理
            ]
        )
    end

    """
    特别解析@带优化：节点⇒像
    """
    function xml_parse_special(parser::TXMLParser_optimized, ::Type{T}, n::XML.Node)::TermImage where {T <: TermImage}
        type::DataType = parse_node_type(n, Narsese.eval) # 获得类型
        args = isnothing(n.children) ? [] : n.children
        terms::Vector = [
            xml_parse(parser, child)::Term
            for child::XML.Node in args
        ] # 广播
        relation_index::Integer = parse(UInt, n.attributes["relation_index"]) # 📌parse不能使用抽象类型
        return type(relation_index, terms...) # 构造原子词项
    end
    
    """
    预打包：像
    - 唯一区别就是有「占位符位置」
    """
    @inline xml_pack(parser::TXMLParser_optimized, t::TermImage)::XML.Node = xml_form_struct(
        Conversion.pack_type_string(t), # 词项类型⇒元素标签
        (relation_index=string(t.relation_index),), # relation_index属性：整数
        [ # 子节点
            xml_pack(parser, term)::XML.Node
            for term::Term in t.terms # 统一预处理
        ]
    )

    """
    特别解析@带优化：节点⇒真值
    """
    function xml_parse_special(::TXMLParser_optimized, ::Type{T}, n::XML.Node)::Truth where {T <: Truth}
        type::DataType = parse_node_type(n, Narsese.eval) # 获得类型
        # 解析其中的f、c值：从类名中获得精度信息
        f_str::String, c_str::String = n.attributes["f"], n.attributes["c"]
        f_type::Type, c_type::Type = type.types # 获取所有类型参数（一定是两个参数，不受别名影响）
        f::f_type, c::c_type = parse(f_type, f_str), parse(c_type, c_str)
        # 构造
        return type(f, c)
    end
    
    """
    预打包：真值⇒XML节点
    - 示例：`%1.0;0.5%` ⇒ `<Truth16 f="1.0", c="0.5"/>`
    """
    @inline xml_pack(::TXMLParser_optimized, t::Truth)::XML.Node = xml_form_struct(
        Conversion.pack_type_string(t), # 词项类型⇒元素标签
        (f=string(t.f),c = string(t.c)), # 属性：f、c
    )

    """
    特别解析@带优化：节点⇒时间戳
    - 【20230814 22:58:23】现在时间戳不一定依赖于「时态」了
        - 故现在只适用于「基础时间戳」
    """
    function xml_parse_special(
        parser::TXMLParser_optimized, 
        ::Type{<:Stamp}, 
        n::XML.Node
        )::Stamp
        type::Type = parse_node_type(n, Narsese.eval) # 获得根类型
        # 【20230814 23:02:33】现只适用于StampBasic
        !(type <: StampBasic) && return n # 返回自身，表示「无法特别解析」
        # 继续解析「基础时间戳」
        tense::Type{<:Tense} = Conversion.parse_type(n.attributes["tense"], Narsese.eval) # 获得类型参数
        # 构造：当结构类型
        args = isnothing(n.children) ? [] : n.children
        return type{tense}(
            (
                # 这里把第四个参数留作默认值
                xml_parse(parser, arg)
                for arg::XML.Node in args
            )...
        )
    end
    
    """
    预打包：基础时间戳⇒XML节点
    - 前提假定：此中Stamp的「类型参数」一定是实例所属类型的「类型参数」
        - 亦即协议：`具体时间戳类{tense <: AbstractTense} <: AbstractStamp`
    
    例：对`StampBasic{Eternal}`
    - `StampBasic{Eternal} <: Stamp`提取出「时态」`Eternal`
    - `StampBasic{Eternal}.name.name == :StampBasic`提取出「母类名」
    - 使用`nameof`获取「母类名」只支持DataType

    【20230814 23:00:01】现在只适用于基础时间戳
    """
    function xml_pack(parser::TXMLParser_optimized, s::StampBasic)::XML.Node
        # 先打包一层得「args全是Node的Expr」
        expr::Expr = Conversion.ast_pack(
            ASTParser, s, xml_pack,
            parser, # 递归回调解析器
        )
        # 再利用里面的「子节点」构建节点
        return xml_form_struct(
            string(typeof(s).name.name), # ⚠未经过API的「类型⇒字符串」转换
            (tense=pack_type_string(get_tense(s)),), # 属性：时态类型
            expr.args
        )
    end

end

begin "入口"
    
    "XML字符串⇒XML节点⇒表达式⇒目标对象"
    function data2narsese(parser::TXMLParser, ::Type, xml::String)::XML_PARSE_TARGETS # 现使用类型=Any的兼容模式
        document::XML.Node = XML.parse(xml, XML.Node) # 使用parse(字符串, Node)实现「字符串→Node」
        @assert document[1].nodetype == XML.Element "文档字符串的首个子节点$(document[1])不是元素！"
        return xml_parse(parser, document[1])::XML_PARSE_TARGETS # 「文档节点」一般只有一个元素
    end
    
    "目标对象⇒表达式⇒XML节点⇒XML字符串"
    function narsese2data(parser::TXMLParser, t::XML_PARSE_TARGETS)::String
        node::XML.Node = xml_pack(parser, t)
        @assert node.nodetype == XML.Element "转换成的子节点$(document[1])不是元素！"
        return XML.write(node)::eltype(parser) # 使用write实现「Node→字符串」
    end
end
