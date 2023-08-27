#=
Lark解析器
- 基于EBNF、Lark及其对应Julia库Lerche
- 可平替JuNarsese内置的字符串转换器

=#

# 导入
using Lerche

# 导出

export LarkParser
export LarkParser_alpha


begin "Lerche部分"
    
    """
    原Narsese语法
    - 原作者：pynars@bowen-xu
    - 文件来源：pynars/Narsese/Parser/narsese.lark
    """
    const ORIGINAL_NARSESE_GRAMMAR::String = raw"""

    // 入口 迁移者注：此元素也可以通过parser中的「start」参数指定
    ?start: task | sentence | term         // 迁移者注：此处转换成Narsese对象，以示明晰（任务暂不使用）
    
    // 基础类型

    // 📌【20230815 18:10:51】Lerche原Lark「无法识别真值」之因：多种「匹配数字」的方法使得「1.」匹配数字后产生「无法识别的亠Token」错误
        // 例如：有「整数」「浮点数」两种识别方式的Lerche解析器，按顺序解析「1.0」时会产生「整数1+浮点数.0」与「浮点数1.0」的歧义
        // 解决方案：只用一种终端Terminal表示数字！
    %import common.NUMBER  // 无符号数字（整数/浮点数，支持科学计数法），详见common.lark

    number: NUMBER

    // %import common.SIGNED_INT -> NUMBER
    // %import common.INT -> NATURAL_NUMBER
    
    ?string: /"[^"]+"/
    ?string_raw:   /([01](\.[0-9]+)?)|(\.[0-9]+)/    ->     float01         // 确保优先级
                |   /[^\-\+\<\>\=\"\&\|\!\.\?\@\~\%\;\,\:\/\\\\\*\#\$\\\[\\\]\{\}\(\)\^ ]+/   // 【20230815 11:13:44】此处的正则不再需要转义
    
    // 任务 & 语句
    task : budget sentence                                                // 待处理的任务【20230822 23:20:07】现在没预算会变成语句，不再需要可选项标记
    ?sentence.0 : (term_nonvar|statement) "." [tense] [truth]  -> judgement // 判断→信念
        | (term_nonvar|statement) "?" [tense]            -> question        // 用于询问「真值」的「问题」
        | (term_nonvar|statement) "!" [tense] [desire]   -> goal            // 待使用「操作」实现的「目标」
        | (term_nonvar|statement) "@" [tense]            -> quest           // 用于询问「欲望值」的「问题」
    
    ?tense : ":!" number ":" -> stamp_time                  // 带时刻事件（【20230816 0:09:41】现在改为直接生成时间戳）
        | ":/:"       -> stamp_future                       // 未来事件（将来时）
        | ":|:"      -> stamp_present                      // 现在事件（现在时）
        | ":\:"      -> stamp_past                         // 过去事件（过去时）
    
    // 📌【20230815 18:14:40】对于检测「真值/欲望值/预算值」区间的操作，留在「构造时」比留在「解析时」更好追踪
    ?desire : truth                                                          // 欲望值：仅仅是「真值」的不同表征
    truth : "%" number [";" number [";" number]] "%"  -> truth           // 两个在[0,1]x(0,1)的实数
    budget.2: "$" number [";" number [";" number]] "$"                // 三个在[0,1]x(0,1)x[0,1]的实数
        
    // 陈述
    ?statement.0 : "<" term copula term ">"                                 // 两个相互关联的词项
        | "(" term copula term ")"                                          // 同上，但使用圆括号表示（兼容NARS-Python）
        // | term                                                           // 一个词项可以被定义为语句？（弃用）
        | "(" op ("," term)* ")"             -> statement_operation1        // 一个要被执行的操作
        | word "(" term ("," term)* ")"      -> statement_operation2        // 同上，但使用「函数调用」的形式表示
    
    ?copula : "-->" -> inheritance                                          // 继承
        | "<->" -> similarity                                               // 相似
        | "{--" -> instance                                                 // 实例
        | "--]" -> property                                                 // 属性
        | "{-]" -> instance_property                                        // 实例属性
        | "==>" -> implication                                              // 蕴含
        | "=/>" -> predictive_implication                                   // 预测性蕴含（将来时）
        | "=|>" -> concurrent_implication                                   // 并发性蕴含（现在时）
        | "=\>" -> retrospective_implication                                // 回顾性蕴含（过去时）
        | "<=>" -> equivalence                                              // 等价
        | "</>" -> predictive_equivalence                                   // 预测性等价（将来时）
        | "<|>" -> concurrent_equivalence                                   // 并发性等价（现在时）
        | "<\>" -> retrospective_equivalence                                // 回顾性等价（过去时）（🆕新加，会被重定向）
    
    // 词项 //
    
    ?term : variable                                                    // 原子词项/变量 【20230814 18:24:30】删去「-> variable_term」
    | term_nonvar
    
    ?term_nonvar: interval                                                          // 间隔
                | word        -> word_term                                          // 原子词项/词语
                | compound_term   -> compound_term                                  // 有内部结构的「复合词项」
                | statement       -> statement_term                                 // 可以被看成词项的陈述
                | op              -> operator_term                                  // 【新】操作
    
    // 原子

    ?word : string_raw | string // /[^\ ]+/                                     // Unicode字符串
    
    ?variable.0 : "$" word -> independent_var              // 独立变量
        | "#" word   -> dependent_var                // 非独变量
        | "?" word   -> query_var                    // 查询变量@问题
    
    ?op.0 : "^" word                                // 【20230814 18:21:09】修改格式
    interval: "+" number
    
    // 复合词项
    ?compound_term : set
        | multi                                     // 带有前缀或中缀算符
        | single                                    // 同上
        | ext_image                                 // 特殊情况，外延像
        | int_image                                 // 特殊情况，内涵像
        | negation                                  // 否定
    
    ?set : int_set
        | ext_set
        // | list_set
    ?int_set   : con_int_set term ("," term)* "]"  -> set                               // 内涵集
    ?ext_set   : con_ext_set term ("," term)* "}"  -> set                               // 外延集
    // list_set: "(" "#" "," term ("," term)+ ")"    
    
    negation  : con_negation term                                                // 否定（前缀形式）
        | "(" con_negation "," term ")"                                                             // 带括号形式       
    int_image : "(" con_int_image "," term ("," term)* ")"                              // 内涵像 🆕限制只有一个像占位符
    ext_image : "(" con_ext_image "," term ("," term)* ")"                              // 外延像
    
    // place_holder : /_+/  // 像占位符【20230815 0:01:41】在word中处理，因为使用「"(" con_int_image "," (term ",")* place_holder ("," term)* ")"」的方法不可行：无法识别是「全下划线字符串（然后误认为没有识别到像占位符）」还是真的「像占位符」
    
    ?multi : "(" con_multi "," term ("," term)+ ")" -> multi_prefix                                 // 前缀算符
        | "(" multi_infix_expr ")"                                                                  // 中缀算符
        | "(" term ("," term)+ ")"                                  -> multi_prefix_product         // 乘积的「，」形式
        | "(" con_product "," term ("," term)* ")"                  -> multi_prefix                 // 乘积的前缀形式
    
    ?single : "(" con_single "," (term|multi_infix_expr) "," (term|multi_infix_expr) ")"  -> single_prefix  // 前缀形式
        | "(" (term|multi_infix_expr) con_single (term|multi_infix_expr) ")"          -> single_infix       // 中缀形式
    
    ?multi_infix_expr : multi_extint_expr
        | multi_intint_expr
        | multi_parallel_expr
        | multi_sequential_expr
        | multi_conj_expr
        | multi_disj_expr
        | multi_prod_expr
    
    // precedence 运算优先级:
    //  "&" > "|" > "&|" > "&/" >  "&&" > "||" > "*"
    ?multi_prod_expr : term6 ("*" term6)+
    ?term6 : (term5|multi_disj_expr)
    ?multi_disj_expr: term5 ("||" term5)+
    ?term5 : (term4|multi_conj_expr)
    ?multi_conj_expr: term4 ("&&" term4)+
    ?term4 : (term3|multi_sequential_expr)
    ?multi_sequential_expr: term3 ("&/" term3)+
    ?term3 : (term2|multi_parallel_expr)
    ?multi_parallel_expr: term2 ("&|" term2)+
    ?term2 : (term1|multi_intint_expr)
    ?multi_intint_expr : term1 ("|" term1)+
    ?term1 : (term|multi_extint_expr)
    ?multi_extint_expr : term ("&" term)+
    
    ?con_multi : "&&"     -> con_conjunction                                // 合取
        | "||"        -> con_disjunction                              // 析取
        | "&|"        -> con_parallel_events                              // 平行事件（合取）
        | "&/"        -> con_sequential_events                // 序列事件（合取）
        | "|"         -> con_intensional_intersection              // 内涵交
        | "&"         -> con_extensional_intersection                              // 外延交
    con_product: "*"                                       // 乘积
    
    ?con_single : "-"     -> con_extensional_difference                             // 外延差
        | "~"         -> con_intensional_difference                             // 内涵差
    ?con_int_set: "["                                 // 内涵集
    ?con_ext_set: "{"                                  // 外延集
    
    ?con_negation : "--"                              // 否定
    
    ?con_int_image : /\\/                              // 内涵像 // 迁移者注：Lerche用字符串表示反斜杠与Lark存在不一致，需要使用正则表达式进行替代
    ?con_ext_image : "/"                              // 外延像
    
    // 忽略空白符
    %import common.WS
    %ignore WS
    
    """;

    """
    Lerche语法树→Narsese对象 转换器
    """
    struct NarseseTransformer <: Lerche.Transformer

    end

    # 规则部分

    "构造语句"
    function form_sentence(type::Type, args)
        n_arg = length(args)
        @assert n_arg > 0 "无效的语句参数长度！"

        # @info type args

        term::Term = args[1] # 首个参数必是词项
        #     n_arg == 1 && type(term) # 内含词项
        #     if n_arg == 2 # 可能是时态，也可能是真值/欲望值
        #         # 时态一定在真值后面
        #         args[2] isa Truth && return type(term, args[2]::Truth)
        #         # 否则就是只有时态无真值
        #         return type(term, args[2]::Type{<:Tense})
        #     elseif n_arg == 3 # 三个就是全了
        #         # 按顺序：词项、时态、真值
        #         return type(args...)
        #     end
        #     #= 或使用「字典+关键字参数形式」：这样可以编写出顺序无关的代码
        #     =#
        kwargs::Dict = Dict()
        @simd for arg in args
            if arg isa Truth
                kwargs[:truth] = arg # 有就是有，没有就用默认值
            elseif arg isa Stamp
                kwargs[:stamp] = arg
            end
        end
        return type(term; kwargs...)
    end

    """
    构造任务
    - 
    """
    function form_task(args)
        budget, sentence = args
        TaskBasic(sentence, budget)
    end

    # 基础类型 #
    @inline_rule number(t::NarseseTransformer, num_str) = JuNarsese.parse_default_float(num_str)

    # 语句 #
    @rule judgement(t::NarseseTransformer, args) = form_sentence(SentenceJudgement, args)

    @rule question(t::NarseseTransformer, args) = form_sentence(SentenceQuestion, args)

    @rule goal(t::NarseseTransformer, args) = form_sentence(SentenceGoal, args)

    @rule quest(t::NarseseTransformer, args) = form_sentence(SentenceQuest, args)

    @rule task(t::NarseseTransformer, args) = form_task(args)

    "调用默认方法，使用默认精度（保证可控性，减少硬编码）"
    @rule truth(t::NarseseTransformer, nums) = JuNarsese.default_precision_truth(
        nums... # f, c, k
    )

    "调用默认方法，使用默认精度（保证可控性，减少硬编码）"
    @rule budget(t::NarseseTransformer, nums) = JuNarsese.default_precision_budget(
        nums... # p, d, q
    )

    # 时间戳
    @inline_rule stamp_time(t::NarseseTransformer, num) = StampBasic{Eternal}(; # 或可用新的Pythonic
        occurrence_time = convert(JuNarsese.Narsese.STAMP_TIME_TYPE, num) # 转换浮点到整数
    )

    @inline_rule stamp_future(t::NarseseTransformer) = StampBasic{TenseFuture}()

    @inline_rule stamp_present(t::NarseseTransformer) = StampBasic{TensePresent}()

    @inline_rule stamp_past(t::NarseseTransformer) = StampBasic{TensePast}()

    # 系词 #
    @inline_rule inheritance(t::NarseseTransformer) = STInheritance

    @inline_rule similarity(t::NarseseTransformer) = STSimilarity

    @inline_rule instance(t::NarseseTransformer) = STInstance

    @inline_rule property(t::NarseseTransformer) = STProperty

    @inline_rule instance_property(t::NarseseTransformer) = STInstanceProperty

    @inline_rule implication(t::NarseseTransformer) = STImplication

    @inline_rule predictive_implication(t::NarseseTransformer) = STImplicationPredictive

    @inline_rule concurrent_implication(t::NarseseTransformer) = STImplicationConcurrent

    @inline_rule retrospective_implication(t::NarseseTransformer) = STImplicationRetrospective

    @inline_rule equivalence(t::NarseseTransformer) = STEquivalence

    @inline_rule predictive_equivalence(t::NarseseTransformer) = STEquivalencePredictive

    @inline_rule concurrent_equivalence(t::NarseseTransformer) = STEquivalenceConcurrent

    @inline_rule retrospective_equivalence(t::NarseseTransformer) = STEquivalenceRetrospective

    # 原子词项
    @inline_rule word_term(t::NarseseTransformer, token) = (
        isnothing(findfirst(r"^_+$", token.value)) ? 
            Word(token.value) : # 没找到：正常词项
            placeholder # 像占位符：全下划线
    ) # 使用.value访问Token的值

    @inline_rule independent_var(t::NarseseTransformer, token) = IVar(token.value)

    @inline_rule dependent_var(t::NarseseTransformer, token) = DVar(token.value)

    @inline_rule query_var(t::NarseseTransformer, token) = QVar(token.value)

    @inline_rule operator_term(t::NarseseTransformer, token) = Operator(token.value)
    
    @inline_rule interval(t::NarseseTransformer, float) = Interval(float)

    @inline_rule compound_term(t::NarseseTransformer, term) = term

    # # 像占位符
    # @inline place_holder(t::NarseseTransformer) = placeholder

    # 陈述
    # args：包含一个Statement对象的数组（参考自parser.py） 「cannot document the following expression」
    @inline_rule statement_term(t::NarseseTransformer, statement) = statement

    # "真正的陈述入口"
    @inline_rule statement(t::NarseseTransformer, t1, copula, t2) = begin
        # @assert length(args) == 3 "无效长度！\nargs = $args"
        Statement{copula}(t1, t2)
    end

    # 作为操作的快捷方式1
    @inline_rule statement_operation1(t::NarseseTransformer, op::Operator, terms::Vararg{Term}) = TermProduct(op, terms...)

    # 作为操作的快捷方式2
    @inline_rule statement_operation2(t::NarseseTransformer, name_token, terms::Vararg{Term}) = TermProduct(Operator(name_token.value), terms...)

    # 复合词项之集合
    @inline_rule set(t::NarseseTransformer, compound_type, terms::Vararg{Term}) = (compound_type)(terms...)

    @inline_rule multi_prefix_product(t::NarseseTransformer, terms::Vararg{Term}) = TermProduct(terms...)

    @inline_rule multi_prefix(t::NarseseTransformer, compound_type, terms::Vararg{Term}) = (compound_type)(terms...)

    @inline_rule single_prefix(t::NarseseTransformer, compound_type, terms::Vararg{Term}) = (compound_type)(terms...)

    @inline_rule single_infix(t::NarseseTransformer, compound_type, terms::Vararg{Term}) = (compound_type)(terms...)
    # 特殊的两个「构造」
    @inline_rule ext_image(t::NarseseTransformer, type, terms::Vararg{Union{Term, Nothing}}) = ExtImage((terms)...)
    # 不知为何会爆Token(__ANON_18, \)
    @inline_rule int_image(t::NarseseTransformer, type, terms::Vararg{Union{Term, Nothing}}) = IntImage((terms)...)

    @inline_rule negation(t::NarseseTransformer, type, terms::Vararg{Union{Term, Nothing}}) = Negation((terms)...)

    @inline_rule con_conjunction(t::NarseseTransformer) = Conjunction

    @inline_rule con_disjunction(t::NarseseTransformer) = Disjunction

    @inline_rule con_parallel_events(t::NarseseTransformer) = ParConjunction

    @inline_rule con_sequential_events(t::NarseseTransformer) = SeqConjunction

    @inline_rule con_int_set(t::NarseseTransformer) = IntSet

    @inline_rule con_ext_set(t::NarseseTransformer) = ExtSet

    @inline_rule con_int_image(t::NarseseTransformer) = IntImage

    @inline_rule con_ext_image(t::NarseseTransformer) = ExtImage

    @inline_rule con_intensional_intersection(t::NarseseTransformer) = IntIntersection

    @inline_rule con_extensional_intersection(t::NarseseTransformer) = ExtIntersection

    @inline_rule con_extensional_difference(t::NarseseTransformer) = ExtDiff

    @inline_rule con_intensional_difference(t::NarseseTransformer) = IntDiff

    @inline_rule con_product(t::NarseseTransformer) = TermProduct

    @inline_rule con_negation(t::NarseseTransformer) = Negation

end

begin "JuNarsese部分"

    """
    基于Lark(Lerche@Julia)的解析器
    - 使用Lerche的语法解析服务
    """
    struct LarkParser <: AbstractParser

        """
        显示用名称
        """
        name::String
        
        """
        Lark语法文本
        """
        grammar::String

        """
        语法树→对象 转换器
        """
        transformer::Lerche.Transformer

        """
        （自动生成）解析器
        """
        parser::Lerche.Lark

        """
        对象→字符串 生成器
        - 参考：PyNARS中直接使用「__str__」重载字符串方法
            - 个人认为此举分散了语法，不好扩展
        """
        stringify_func

        """
        内部构造函数：根据语法、转换器、转字符串函数（不然就纯解析）封装Lark解析器
        """
        function LarkParser(
            name::String,
            grammar::String, 
            transformer::Lerche.Transformer,
            stringify_func::Function,
            )
            new(
                name,
                grammar,
                transformer,
                Lerche.Lark( # 直接用transformer自动生成，原transformer字段暂仅存储用
                    grammar;
                    parser = "lalr",
                    lexer="standard", 
                    transformer=transformer,
                ),
                stringify_func,
            )
        end

        """
        内部构造函数，但自动封装stringify解析器
        """
        function LarkParser(
            name::String,
            grammar::String, 
            transformer::Lerche.Transformer,
            stringify_parser::Conversion.AbstractParser,
            args... # 支持自定义额外参数
            )
            new(
                name,
                grammar,
                transformer,
                Lerche.Lark( # 直接用transformer自动生成，原transformer字段暂仅存储用
                    grammar;
                    parser = "lalr",
                    lexer="standard", 
                    transformer=transformer,
                ),
                object -> Conversion.narsese2data(stringify_parser, object, args...),
            )
        end

        """
        （WIP）从字符串解析器中导入
        1. 根据内容自动生成语法
        2. 自动生成转换器
        3. 内联字符串解析器
        4. 跳转到第一个构造函数
        """
        function LarkParser(
            name::String,
            parser::Conversion.StringParser
            )
            # 1. 根据内容自动生成语法


            # 2. 自动生成转换器


            # 3. 内联字符串解析器


            # 4. 跳转到第一个构造函数


        end

    end

    """
    定义「JSON转换」的「目标类型」
    - JSON字串↔Narsese对象
    """
    const LARK_PARSE_TARGETS::Type = Conversion.DEFAULT_PARSE_TARGETS

    "目标类型：Narsese对象"
    Conversion.parse_target_types(::LarkParser) = LARK_PARSE_TARGETS

    "数据类型：以JSON表示的字符串"
    Base.eltype(::LarkParser)::Type = String

    # 重载「字符串宏の快捷方式」:lark
    @register_parser_string_flag :lark => LarkParser_alpha

    # 字符串显示
    @redirect_SRS parser::LarkParser parser.name

    begin "具体转换实现"
        
        "字符串⇒目标对象"
        @inline function data2narsese(parser::LarkParser, ::Type, s::String)::LARK_PARSE_TARGETS
            return Lerche.parse(parser.parser, s)
        end
        
        "借用字符串解析器"
        @inline function narsese2data(parser::LarkParser, t::LARK_PARSE_TARGETS)::String
            return parser.stringify_func(t)
        end

    end


    # 定义 #

    const LarkParser_alpha::LarkParser = LarkParser(
        "LarkParser_alpha",
        ORIGINAL_NARSESE_GRAMMAR,
        NarseseTransformer(),
        Conversion.StringParser_ascii
    )

end
