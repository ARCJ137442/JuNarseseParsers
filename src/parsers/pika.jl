# 导入
import PikaParser as P

# 导出

export PikaParser
export PikaParser_alpha, PikaParser_ascii, PikaParser_latex, PikaParser_han


begin "Pika部分"

    "快捷构造：[terminal]" #  【20230816 17:05:50】这样的实现容易引发歧义：「First with non-terminal epsilon match」
    @inline P_one(terminal) = P.first(
        terminal,
        P.epsilon,
    )

    "快捷构造：在无法使用「空字符ϵ」做前缀时，采用「序列匹配」的方式做「可选前缀」"
    @inline P_prefix(prefix, terminal) = P.first(
        P.seq( # 最好有前缀
            prefix,
            terminal,
        ), # 不然没前缀
        terminal,
    )

    "快捷构造：many × seq" # 函数复合，从右向左优先
    const P_many_seq::Function = P.many ∘ P.seq
    const P_tie_seq::Function = P.tie ∘ P.seq
    const P_tie_first::Function = P.tie ∘ P.first

    # 原解析器 #
    const NARSESE_RULES_ALPHA::Dict = Dict(
        # 元：开头/忽略 #
        :top => P.seq( # 顶层，支持删去包围的空白符
            :ws, # 前导空白符
            :narsese, # 📌task尚不支持                           
            # :ws, # 后缀空白符(其它地方的代码已有)
        ),
        :narsese => P.first(
            :task,
            :sentence,
            :term,
        ),
        # 基础数据类型 #
        # 空白: 不限量个空白字符
        :ws => P.many(P.satisfy(isspace)),
        :ws_some => P.some(P.satisfy(isspace)), # 至少一个空白符
        # 数字
        :digit => P.satisfy(isdigit), # 直接传递不解析
        :uint => P.some(:digit), # 【20230816 16:11:12】some：至少有一个
        :unsigned_number => P.first(
            P.seq( # `XXX[.XXX]`
                P.some(:digit), # 【20230816 16:31:36】many：有多个/没有
                P.first(
                    P.seq( # `.XXXXXX`
                        P.token('.'), 
                        P.some(:digit)
                    ), 
                    P.epsilon # 或者为空
                ),
            ),
            P.seq( # `.XXX` (优先匹配长的)
                P.token('.'), 
                P.some(:digit),
            ),
        ),
        # 用于词项名
        :identifier => P.seq( # 与Julia变量名标准一致的标识符
            P.satisfy(Base.is_id_start_char), # 调用Julia内部识别变量名的方法✅
            P_many_seq(
                P.not_followed_by(:copula), # 【20230820 23:43:23】系词是保留字，不能把系词吃了！
                P.satisfy(Base.is_id_char), # 调用Julia内部识别变量名的方法✅
            )
        ),
        # 用于分隔符
        :compound_separator => P.first(
            P.token(','), # 相当于「强制断开」
            P.followed_by(:ws_some), # 若前面已经有空白符分隔，则「自动补全分隔符」
        ), # 纯分隔符，不加尾缀
        # 任务 #
        :task => P.seq( # 预算值 语句
            :budget, :ws, # 可选前缀「预算值」
            :sentence, # 语句
        ),
        :budget => P.seq(
            P.token('$'), :ws,
            :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
            P.token(';'), :ws,
            :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
            P.token(';'), :ws,
            :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
            P.token('$'),
        ),
        # 语句 #
        :sentence => P.seq( # 词项 标点 [时间戳] [真值] # TODO：是否可以直接在时间戳上加个候选项「:ws」以实现统一管理「默认值」？
            :term, :ws, # 内含之词项，至于「不能用变量当语句中的词项」留给「构造方法の合法性检查」
            :punctuation, :ws, # 标点，用于决定语句类型
            :stamp, :ws, # 时间戳(可为空)
            :truth, :ws, # 真值(可为空)
        ),
        :punctuation => P.first(
            :punct_judgement => P.token('.'),
            :punct_question  => P.token('?'),
            :punct_goal      => P.token('!'),
            :punct_quest     => P.token('@'),
        ),
        :truth => P.first( # 不直接使用
            :truth_valued => P.seq(
                P.token('%'), :ws,
                :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
                P_many_seq( # 具体多少个，留给「构造方法の合法性检查」
                    P.token(';'), :ws,
                    :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
                ),
                P.token('%'),
            ),
            :truth_default => P.epsilon,
        ),
        :stamp => P.first( # 不允许多余空白
            # 固定时态时间戳
            :stamp_past    => P.tokens(raw":\:"), # 过去时
            :stamp_present => P.tokens(raw":|:"), # 过去时
            :stamp_future  => P.tokens(raw":/:"), # 过去时
            # 带时态时间戳
            :stamp_timed => P.seq(
                P.tokens(":!"), # 序列
                :uint, # 无符号整数
                P.token(':'),
            ),
            # 没时间戳
            :stamp_default => P.epsilon,
        ),
        # 词项 #
        # 总领
        :term => P.first( # 陈述、复合、原子
            :statement, # 陈述作为词项
            :compound, # 复合词项
            :atom, # 原子词项
        ),
        # 原子
        :atom => P.first(
            :i_var    => P.seq(P.token('\$'), :identifier),
            :d_var    => P.seq(P.token('#'), :identifier),
            :q_var    => P.seq(P.token('?'), :identifier),
            :operator => P.seq(P.token('^'), :identifier),
            :interval => P.seq(P.token('+'), :uint), # 区间`+非负整数`
            # 像占位符：全下划线
            :placeholder => P.some(P.token('_')), # 新的「像占位符」
            :word => P.seq(:identifier), # 单序列
        ),
        # 复合
        :compound_connector => P.first(
            # 一元算符
            :compound_connector_unary => P.first(
                :negation => P.tokens("--"),
            ),
            # 二元/多元运算符（都支持`A * B`的形式）
            :compound_connector_multi => P.first(
                :ext_difference   => P.token('-'),
                :int_difference   => P.token('~'),
                # 多元运算符
                :conjunction      => P.tokens("&&"), # 字符多的比少的优先！避免「被提前捞走」产生多余字符引起的「token重复谬误」
                :disjunction      => P.tokens("||"),
                :par_conjunction  => P.tokens("&|"),
                :seq_conjunction  => P.tokens("&/"),
                :product          => P.tokens("*"),
                :ext_intersection => P.token('&'),
                :int_intersection => P.token('|'),
                # :rev_conjunction => P.tokens(raw"&\"), # 为了对称🤷
            ),
        ),
        # 刻画形如`词项, 词项, ..., 词项`的**内联**语法
        :inner_compound => P_tie_seq( # 📝此处的「tie」相当于Lark中的「内联」与Julia中的「@inline」，会把解析出的参数组展开到被包含的地方，且支持同时匹配多个
            :term, # 不允许空集存在
            P_many_seq( # 任意多词项
                :ws, 
                :compound_separator, :ws,
                :term,
            ), # 无尾缀空白符
        ),
        # 【20230821 23:09:19】现在不再需要：`term`规则自带像占位符
        # 中缀表达式
        :inner_compound_infix => P.seq(
            :term, :ws,
            # 【20230821 23:39:38】因「短运算符截断」与「如何优先向前搜索」问题，暂时不区分运算符优先级（但括号是可选的）
                # 优先级：外延交& 内涵交| 平行合取&| 序列合取&/ 合取&& 析取|| 乘积*
                # 例如：`A&B|B&C` = (A&B)|(B&C)
            :compound_connector, :ws,
            :term,
        ), # 无尾缀空白符
        :compound => P.first( # 复合词项
            # 外延集
            :ext_set => P.seq(
                P.token('{'), :ws,
                :inner_compound, :ws, # 不允许空集存在
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P.token('}'), :ws,
            ),
            # 内涵集
            :int_set => P.seq(
                P.token('['), :ws,
                :inner_compound, :ws, # 不允许空集存在
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P.token(']'), :ws,
            ),
            # 外延像
            :ext_image => P.seq(
                P.token('('), :ws,
                P.token('/'), :ws,
                :compound_separator, :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P.token(')'), :ws,
            ),
            # 内涵像
            :int_image => P.seq(
                P.token('('), :ws,
                P.token('\\'), :ws,
                :compound_separator, :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P.token(')'), :ws,
            ),
            # `一元连接符 词项`的形式
            :compound_prefix_unary => P.seq(
                :compound_connector_unary, :ws,
                :term, :ws,
            ),
            # 正常的`(连接符, 词项...)`形式
            :compound_prefix => P.seq(
                P.token('('), :ws,
                :compound_connector, :ws,
                :compound_separator, :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P.token(')'), :ws,
            ),
            # 「多元运算符作二元运算符」的`词项 连接符 词项`形式
            :compound_infix => P.seq(
                P.token('('), :ws,
                :inner_compound_infix, :ws,
                P.token(')'), :ws,
            ),
            # 🆕裸露的「复合词项」`A*B == (*,A,B)`中缀形式
            #= 已知漏洞：
                pa("(A-->B) && (C-->D) ")
                    <A --> B>
                    预期：(&&, <A --> B>, <C --> D>)
                pa("(A)-->(D)")
                    (*, A)
                    预期：<(*, A) --> (*, D)>
                =#
            :compound_infix_inline => P.seq(
                :inner_compound_infix, :ws, # 允许继续嵌套而无需括号，但是右结合如「`(A-B-C)`=`(A-(B-C))`」
            ),
            # 兜底：「无连接符⇒默认乘积`*`」的`(词项...)` => `(*, 词项...)` 形式
            :compound_no_prefix => P.seq(
                P.token('('), :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P.token(')'), :ws,
            ),
        ),
        # 刻画内部陈述：词项 系词(陈述类型) 词项
        :inner_statement => P.seq(
            :term, :ws,
            :copula, :ws, # 只实现一般形式，合法性限定留给「构造方法の合法性检查」
            :term, :ws,
        ),
        # 陈述
        :statement => P.first(
            # 正常的「尖括号」形式：`<term copula term>`
            :statement_angle => P.seq(
                P.token('<'), :ws,
                :inner_statement,
                P.token('>'), :ws,
            ),
            # 「圆括号」形式（仿NARS-Python）：`(term copula term)`
            :statement_round => P.seq(
                P.token('('), :ws,
                :inner_statement,
                P.token(')'), :ws,
            ),
            # 类似「函数调用」的`操作(词项...)` => `(*, ⇑操作, 词项...)` 形式
            :statement_ocall => P.seq(
                :identifier, :ws,
                P.token('('), :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P.token(')'), :ws,
            ),
            # 🆕简略的「无括号」形式：`term copula term`
            :statement_inline => P.seq(
                P.not_followed_by( # 不能在识别到前面的情况时，再搞一个嵌套「<<A-->B>>」出来
                    P.first(
                        P.token('('),
                        P.token('<'),
                    )
                ),
                :inner_statement,
            ),
        ),
        :copula => P.first(
            # 主系词
            :inheritance               => P.tokens("-->"),
            :similarity                => P.tokens("<->"),
            :implication               => P.tokens("==>"),
            :equivalence               => P.tokens("<=>"),
            # 副系词
            :instance                  => P.tokens("{--"),
            :property                  => P.tokens("--]"),
            :instance_property         => P.tokens("{-]"),
            # 时序蕴含/等价
            :predictive_implication    => P.tokens(raw"=/>"),
            :concurrent_implication    => P.tokens(raw"=|>"),
            :retrospective_implication => P.tokens(raw"=\>"),
            :predictive_equivalence    => P.tokens(raw"</>"),
            :concurrent_equivalence    => P.tokens(raw"<|>"),
            :retrospective_equivalence => P.tokens(raw"<\>"), # 此「重定向行为」留给「数据类型构造」阶段，最大化减少语法复杂度/非对称性
        ),
    )

    # 字符串解析器转译部分 #
    "_txt_to_token: 在基于字符的解析器中，将字符串/字符解析为对应Token标识符（空字串⇒空串表达式）"
    P_token(str::AbstractString)::P.Clause = isempty(str) ? P.epsilon : P.tokens(str)
    P_token(chr::AbstractChar)::P.Clause = P.token(chr)

    generate_rule_from_string_parser(parser::JuNarsese.Conversion.StringParser)::Dict = Dict(
        # 元：开头/忽略 #
        :top => P.seq( # 顶层，支持删去包围的空白符
            :ws, # 前导空白符
            :narsese, # 📌task尚不支持
            # :ws, # 后缀空白符(其它地方的代码已有)
        ),  
        :narsese => P.first(
            :task,
            :sentence,
            :term,
        ),
        # 基础数据类型 #
        # 空白: 不限量个空白字符
        :ws => P.epsilon, # 【20230820 23:00:37】不要再预设空白符了，这个「处理空白符」的任务已交给「预处理函数」
        :ws_some => P.some(P.satisfy(isspace)), # 至少一个空白符
        # 数字
        :digit => P.satisfy(isdigit), # 直接传递不解析
        :uint => P.some(:digit), # 【20230816 16:11:12】some：至少有一个
        :unsigned_number => P.first(
            P.seq( # `XXX[.XXX]`
                P.some(:digit), # 【20230816 16:31:36】many：有多个/没有
                P.first(
                    P.seq( # `.XXXXXX`
                        P.token('.'), 
                        P.some(:digit)
                    ), 
                    P.epsilon # 或者为空
                ),
            ),
            P.seq( # `.XXX` (优先匹配长的)
                P.token('.'), 
                P.some(:digit),
            ),
        ),
        # 用于词项名
        :identifier => P.seq( # 与Julia变量名标准一致的标识符
            P.satisfy(Base.is_id_start_char), # 调用Julia内部识别变量名的方法✅
            P_many_seq(
                P.not_followed_by(:copula), # 【20230820 23:43:23】系词是保留字，不能把系词吃了！
                P.satisfy(Base.is_id_char), # 调用Julia内部识别变量名的方法✅
            )
        ),
        # 用于分隔符
        :compound_separator => P.first(
            P_token(parser.comma_d2t), # ⚠分隔符可能是空白符（如LaTeX）
            P.followed_by(:ws_some), # 前面已经是空格符了，就默认在此处补全分隔符
        ), # 纯分隔符，不加尾缀
        # 任务 #
        :task => P.seq( # 预算值 语句
            :budget, :ws, # 可选前缀「预算值」
            :sentence, # 语句
        ),
        :budget => P.seq(
            P_token(parser.budget_brackets[1]), :ws,
            :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
            P_token(parser.budget_separator), :ws,
            :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
            P_token(parser.budget_separator), :ws,
            :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
            P_token(parser.budget_brackets[2]), 
        ),
        # 语句 #
        :sentence => P.seq( # 词项 标点 [时间戳] [真值] # TODO：是否可以直接在时间戳上加个候选项「:ws」以实现统一管理「默认值」？
            :term, :ws, # 内含之词项，至于「不能用变量当语句中的词项」留给「构造方法の合法性检查」
            :punctuation, :ws, # 标点，用于决定语句类型
            :stamp, :ws, # 时间戳(可为空)
            :truth, :ws, # 真值(可为空)
        ),
        :punctuation => P.first(
            :punct_judgement => P_token(parser.punctuation_dict[PunctuationJudgement]),
            :punct_question  => P_token(parser.punctuation_dict[PunctuationQuestion]),
            :punct_goal      => P_token(parser.punctuation_dict[PunctuationGoal]),
            :punct_quest     => P_token(parser.punctuation_dict[PunctuationQuest]),
        ),
        :truth => P.first( # 不直接使用
            :truth_valued => P.seq(
                P_token(parser.truth_brackets[1]), :ws,
                :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
                P_many_seq( # 具体多少个，留给「构造方法の合法性检查」
                    P_token(parser.truth_separator), :ws,
                    :unsigned_number, :ws, # 数值范围限定留给「构造方法の合法性检查」
                ),
                P_token(parser.truth_brackets[2]),
            ),
            :truth_default => P.epsilon,
        ),
        :stamp => P.first( # 不允许多余空白
            # 带时刻时间戳
            :stamp_timed => P.seq(
                P_token(parser.timed_stamp_brackets[1]), # 序列
                :uint, # 无符号整数
                P_token(parser.timed_stamp_brackets[2]),
            ),
            # 固定时态时间戳
            :stamp_past    => P_token(parser.tense_dict[Past]), # 过去时
            :stamp_present => P_token(parser.tense_dict[Present]), # 现在时
            :stamp_future  => P_token(parser.tense_dict[Future]), # 未来时
            :stamp_default => P_token(parser.tense_dict[Eternal]), # 永恒
        ),
        # 词项 #
        # 总领
        :term => P.first( # 陈述、复合、原子
            :statement, # 陈述作为词项
            :compound, # 复合词项
            :atom, # 原子词项
        ),
        # 原子
        :atom => P.first(
            :i_var    => P.seq(P_token(parser.atom_prefixes[IVar]), :identifier),
            :d_var    => P.seq(P_token(parser.atom_prefixes[DVar]), :identifier),
            :q_var    => P.seq(P_token(parser.atom_prefixes[QVar]), :identifier),
            :operator => P.seq(P_token(parser.atom_prefixes[Operator]), :identifier),
            :interval => P.seq(P_token(parser.atom_prefixes[Interval]), :uint), # 区间`+非负整数`
            # 像占位符：全下划线
            :placeholder => P_token(parser.atom_prefixes[PlaceHolder]), # 新的「像占位符」
            :word => P.seq(:identifier), # 单序列
        ),
        # 复合
        :compound_connector => P.first(
            # 一元算符
            :compound_connector_unary => P.first(
                :negation => P_token(parser.compound_symbols[Negation]),
            ),
            # 二元/多元运算符（都支持`A * B`的形式）
            :compound_connector_multi => P.first(
                :ext_difference   => P_token(parser.compound_symbols[ExtDiff]),
                :int_difference   => P_token(parser.compound_symbols[IntDiff]),
                # 多元运算符
                :conjunction      => P_token(parser.compound_symbols[Conjunction]), # 字符多的比少的优先！避免「被提前捞走」产生多余字符引起的「token重复谬误」
                :disjunction      => P_token(parser.compound_symbols[Disjunction]),
                :par_conjunction  => P_token(parser.compound_symbols[ParConjunction]),
                :seq_conjunction  => P_token(parser.compound_symbols[SeqConjunction]),
                :product          => P_token(parser.compound_symbols[TermProduct]),
                :ext_intersection => P_token(parser.compound_symbols[ExtIntersection]),
                :int_intersection => P_token(parser.compound_symbols[IntIntersection]),
                # :rev_conjunction => P_token(parser.compound_symbols[RevConjunction]), # 为了对称🤷
            ),
        ),
        # 刻画形如`词项, 词项, ..., 词项`的**内联**语法
        :inner_compound => P_tie_seq( # 📝此处的「tie」相当于Lark中的「内联」与Julia中的「@inline」，会把解析出的参数组展开到被包含的地方，且支持同时匹配多个
            :term, # 不允许空集存在
            P_many_seq( # 任意多词项
                :ws, 
                :compound_separator, :ws,
                P.first(:placeholder, :term),
            ), # 无尾缀空白符
        ),
        # 【20230821 23:06:15】现在`:term`规则默认包含「像占位符」，不再需要`:inner_compound_with_placeholder`了
        :compound => P.first( # 复合词项
            # 外延集
            :ext_set => P.seq(
                P_token(parser.compound_brackets[ExtSet][1]), :ws,
                :inner_compound, :ws, # 不允许空集存在
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P_token(parser.compound_brackets[ExtSet][2]), :ws,
            ),
            # 内涵集
            :int_set => P.seq(
                P_token(parser.compound_brackets[IntSet][1]), :ws,
                :inner_compound, :ws, # 不允许空集存在
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P_token(parser.compound_brackets[IntSet][2]), :ws,
            ),
            # 外延像
            :ext_image => P.seq(
                P_token(parser.compound_brackets[Compound][1]), :ws,
                P_token(parser.compound_symbols[ExtImage]), :ws,
                :compound_separator, :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P_token(parser.compound_brackets[Compound][2]), :ws,
            ),
            # 内涵像
            :int_image => P.seq(
                P_token(parser.compound_brackets[Compound][1]), :ws,
                P_token(parser.compound_symbols[IntImage]), :ws,
                :compound_separator, :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P_token(parser.compound_brackets[Compound][2]), :ws,
            ),
            # `一元连接符 词项`的形式
            :compound_prefix_unary => P.seq(
                :compound_connector_unary, :ws,
                :term, :ws,
            ),
            # 正常的`(连接符, 词项...)`形式
            :compound_prefix => P.seq(
                P_token(parser.compound_brackets[Compound][1]), :ws,
                :compound_connector, :ws,
                :compound_separator, :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P_token(parser.compound_brackets[Compound][2]), :ws,
            ),
            # 「无连接符⇒默认乘积`*`」的`(词项...)` => `(*, 词项...)` 形式
            :compound_no_prefix => P.seq(
                P_token(parser.compound_brackets[Compound][1]), :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P_token(parser.compound_brackets[Compound][2]), :ws,
            ),
        ),
        # 刻画内部陈述：词项 系词(陈述类型) 词项
        :inner_statement => P.seq(
            :term, :ws,
            :copula, :ws, # 只实现一般形式，合法性限定留给「构造方法の合法性检查」
            :term, :ws,
        ),
        # 陈述
        :statement => P.first(
            # 正常的「尖括号」形式：`<term copula term>`
            :statement_angle => P.seq(
                P_token(parser.compound_brackets[Statement][1]), :ws,
                :inner_statement,
                P_token(parser.compound_brackets[Statement][2]), :ws,
            ),
            # 「圆括号」形式（仿NARS-Python）：`(term copula term)`
            :statement_round => P.seq(
                P_token(parser.compound_brackets[Compound][1]), :ws,
                :inner_statement,
                P_token(parser.compound_brackets[Compound][2]), :ws,
            ),
            # 类似「函数调用」的`操作(词项...)` => `(*, ⇑操作, 词项...)` 形式
            :statement_ocall => P.seq(
                :identifier, :ws,
                P_token(parser.compound_brackets[Compound][1]), :ws,
                :inner_compound, :ws,
                P_one(:compound_separator), :ws, # 「尾后逗号」
                P_token(parser.compound_brackets[Compound][2]), :ws,
            ),
            # 🆕简略的「无括号」形式：`term copula term`
            :statement_inline => P.seq(
                P.not_followed_by( # 不能在识别到前面的情况时，再搞一个嵌套「<<A-->B>>」出来
                    P.first(
                        P_token(parser.compound_brackets[Compound][1]),
                        P_token(parser.compound_brackets[Statement][1]),
                    )
                ),
                :inner_statement,
            ),
        ),
        :copula => P.first(
            # 主系词
            :inheritance               => P_token(parser.copula_dict[STInheritance]),
            :similarity                => P_token(parser.copula_dict[STSimilarity]),
            :implication               => P_token(parser.copula_dict[STImplication]),
            :equivalence               => P_token(parser.copula_dict[STEquivalence]),
            # 副系词
            :instance                  => P_token(parser.copula_dict[STInstance]),
            :property                  => P_token(parser.copula_dict[STProperty]),
            :instance_property          => P_token(parser.copula_dict[STInstanceProperty]),
            # 时序蕴含/等价
            :predictive_implication        => P_token(parser.copula_dict[STImplicationPredictive]),
            :concurrent_implication        => P_token(parser.copula_dict[STImplicationConcurrent]),
            :retrospective_implication     => P_token(parser.copula_dict[STImplicationRetrospective]),
            :predictive_equivalence        => P_token(parser.copula_dict[STEquivalencePredictive]),
            :concurrent_equivalence        => P_token(parser.copula_dict[STEquivalenceConcurrent]),
            :retrospective_equivalence     => P_token(parser.copula_dict[STEquivalenceRetrospective]), # 此「重定向行为」留给「数据类型构造」阶段，最大化减少语法复杂度/非对称性
        ),
    )

    "默认的语法转换器"
    const NARSESE_DEFAULT_FOLDS::Dict = Dict(
        #= 基础数据类型 =#
        # 空值直接返回第一个
        :ws         => (str, subvals) -> nothing,
        # 标识符直接返回字符串
        :identifier => (str, subvals) -> str,
        # 数值
        :uint            => (str, subvals) -> JuNarsese.parse_default_uint(str),
        :unsigned_number => (str, subvals) -> JuNarsese.parse_default_float(str),
        #= 任务 =#
        # subvals结构：**预算值** 空白 **语句** ...
        :task   => (str, subvals) -> JuNarsese.TaskBasic(subvals[3], subvals[1]),
        # subvals结构：括弧 空白 **无符号数** 空白[分隔符 空白 **无符号数** 空白]+ 括弧 空白
        :budget => (str, subvals) -> JuNarsese.default_precision_budget(subvals[3:4:end]...),
        #= 语句 =#
        # 语句 subvals结构：**词项** 空白 **标点(构造器)** 空白 时间戳 空白 真值 空白
        :sentence => (str, subvals) -> subvals[3](
            subvals[1]; # 内含之词项
            stamp = isnothing(subvals[5]) ? JuNarsese.StampBasic{Eternal}() : subvals[5],
            truth = isnothing(subvals[7]) ? JuNarsese.default_precision_truth() : subvals[7], # 真值
        ),
        # 标点→语句类型
        :punct_judgement => (str, subvals) -> JuNarsese.SentenceJudgement,
        :punct_question  => (str, subvals) -> JuNarsese.SentenceQuestion,
        :punct_goal      => (str, subvals) -> JuNarsese.SentenceGoal,
        :punct_quest     => (str, subvals) -> JuNarsese.SentenceQuest,
        # 真值 subvals结构：括弧 空白 **无符号数** 空白[分隔符 空白 **无符号数** 空白]+ 括弧 空白
        :truth_valued => (str, subvals) -> JuNarsese.default_precision_truth(subvals[3], subvals[5]), # 【20230818 23:52:38】不知为何第四个的空白符被省掉了。。。
        :truth_default => (str, subvals) -> JuNarsese.default_precision_truth(), # 不知为何就是不起效：`P.epsilon`似乎没法直接识别
        # 固定时态时间戳：直接返回相应的「基础时间戳」
        :stamp_past    => (str, subvals) -> JuNarsese.StampBasic{Past}(),
        :stamp_present => (str, subvals) -> JuNarsese.StampBasic{Present}(),
        :stamp_future  => (str, subvals) -> JuNarsese.StampBasic{Future}(),
        :stamp_default => (str, subvals) -> JuNarsese.StampBasic{Eternal}(), # 默认永恒 # 不知为何就是不起效：`P.epsilon`似乎没法直接识别
        # 带时刻时间戳 subvals结构：括弧 **无符号整数** 括弧
        :stamp_timed   => (str, subvals) -> JuNarsese.StampBasic{Eternal}(occurrence_time = subvals[2]),
        #= 词项 =#
        # 原子 #
        # subvals结构：**名称**
        :word        => (str, subvals) -> JuNarsese.Word(str), # 但还是直接使用字符串
        # 像占位符
        :placeholder => (str, subvals) -> JuNarsese.placeholder,
        # 变量
        :i_var       => (str, subvals) -> JuNarsese.IVar(subvals[2]), # subvals结构：前导字符 **名称**
        :q_var       => (str, subvals) -> JuNarsese.QVar(subvals[2]), # subvals结构：前导字符 **名称**
        :d_var       => (str, subvals) -> JuNarsese.DVar(subvals[2]), # subvals结构：前导字符 **名称**
        # 间隔
        :interval    => (str, subvals) -> JuNarsese.Interval(subvals[2]), # subvals结构：前导字符 **名称**；使用间隔的字符串兼容方法
        # 操作
        :operator    => (str, subvals) -> JuNarsese.Operator(subvals[2]), # subvals结构：前导字符 **名称**
        # 复合词项 #
        # 连接符⇒词项类型
        :negation         => (str, subvals) -> JuNarsese.Negation,
        :ext_difference   => (str, subvals) -> JuNarsese.ExtDifference,
        :int_difference   => (str, subvals) -> JuNarsese.IntDifference,
        :conjunction      => (str, subvals) -> JuNarsese.Conjunction,
        :disjunction      => (str, subvals) -> JuNarsese.Disjunction,
        :par_conjunction  => (str, subvals) -> JuNarsese.ParConjunction,
        :seq_conjunction  => (str, subvals) -> JuNarsese.SeqConjunction,
        :product          => (str, subvals) -> JuNarsese.TermProduct,
        :ext_intersection => (str, subvals) -> JuNarsese.ExtIntersection,
        :int_intersection => (str, subvals) -> JuNarsese.IntIntersection,
        # 内联语法: 返回列表中的非空子元素（nothing从分隔符等来）
        # 【20230818 15:08:25 假定】（使用了`P.tie`）subvals结构：词项...
        :inner_compound       => (str, subvals) -> subvals,
        # subvals结构：**词项** 空白 **连接词(复合词项类型)** 空白 **词项**
        :inner_compound_infix => (str, subvals) -> subvals[3](subvals[1], subvals[5]),
        # 具体复合词项
        :ext_set   => (str, subvals) -> JuNarsese.ExtSet(subvals[3]), # subvals结构：括号 空白 *词项集合* 空白 括号 空白
        :int_set   => (str, subvals) -> JuNarsese.IntSet(subvals[3]), # subvals结构：括号 空白 *词项集合* 空白 括号 空白
        :ext_image => (str, subvals) -> TermImage{Extension}(subvals[7]), # subvals结构：括弧 空白 连接符 空白 词项分隔符 空白 **含占位符词项** ...
        :int_image => (str, subvals) -> TermImage{Intension}(subvals[7]), # subvals结构：括弧 空白 连接符 空白 词项分隔符 空白 **含占位符词项** ...
        :compound_prefix_unary => (str, subvals) -> subvals[1](subvals[3]), # subvals结构：**一元连接符(构造器)** 空白 **词项** 空白
        :compound_prefix       => (str, subvals) -> subvals[3](subvals[7]), # subvals结构：括弧 空白 **多元连接符(构造器)** 空白 词项分隔符 空白 **词项数组** ...
        :compound_no_prefix    => (str, subvals) -> TermProduct(subvals[3]), # subvals结构：括弧 空白 词项数组 ...
        # 陈述 #
        # 本体
        # subvals结构：**词项** 空白 **系词(陈述类型)** 空白 **词项** ...
        :inner_statement => (str, subvals) -> Statement{subvals[3]}(subvals[1], subvals[5]),
        # subvals结构：括弧 空白 **内陈述(陈述)** ...
        :statement_angle => (str, subvals) -> subvals[3],
        # subvals结构：括弧 空白 **内陈述(陈述)** ...
        :statement_round => (str, subvals) -> subvals[3],
        # subvals结构：标识符 空白 括弧 空白 **参数列表** ...
        :statement_ocall => (str, subvals) -> Inheritance( # subvals结构：**标识符(操作名)** 空白 括弧 空白 **词项数组** 空白 **词项数组** ...
            TermProduct(subvals[5]),
            Operator(subvals[1]),
        ),
        # subvals结构：排除括弧 **内陈述(陈述)**
        :statement_inline => (str, subvals) -> subvals[2],
        # 主系词
        :inheritance               => (str, subvals) -> STInheritance,
        :similarity                => (str, subvals) -> STSimilarity,
        :implication               => (str, subvals) -> STImplication,
        :equivalence               => (str, subvals) -> STEquivalence,
        # 副系词
        :instance                  => (str, subvals) -> STInstance,
        :property                  => (str, subvals) -> STProperty,
        :instance_property         => (str, subvals) -> STInstanceProperty,
        # 时序蕴含/等价
        :predictive_implication    => (str, subvals) -> STImplicationPredictive,
        :concurrent_implication    => (str, subvals) -> STImplicationConcurrent,
        :retrospective_implication => (str, subvals) -> STImplicationRetrospective,
        :predictive_equivalence    => (str, subvals) -> STEquivalencePredictive,
        :concurrent_equivalence    => (str, subvals) -> STEquivalenceConcurrent,
        :retrospective_equivalence => (str, subvals) -> STEquivalenceRetrospective,
    )

    function default_fold(str, subvals) # , show=true
        # show && @info "default_fold!" str subvals
        # 返回第一个非空组分
        for element in subvals # 不使用findfirst
            !isnothing(element) && return element
        end
        return nothing # 默认空值
        # show && @info "nothing default_fold!" str subvals nothing
    end

end

begin "JuNarsese部分"

    """
    基于Lark(Lerche@Julia)的解析器
    - 使用Lerche的语法解析服务
    """
    struct PikaParser <: AbstractParser

        """
        显示用名称
        """
        name::String
        
        """
        Pika语法结构
        """
        rules::Dict
        
        """
        Pika语法结构
        """
        grammar::P.Grammar

        """
        语法树→对象 转换器
        """
        folds::Dict

        """
        语法解析起点
        - 需要在具体解析时使用
        """
        start::Symbol

        """
        默认转换函数
        """
        default_fold::Function

        """
        对象→字符串 生成器
        - 参考：PyNARS中直接使用「__str__」重载字符串方法
            - 个人认为此举分散了语法，不好扩展
        """
        stringify_func::Function

        """
        字串预处理函数
        - 对接原生字符串转换器中的「预处理」函数
        """
        preprocess_func::Function

        """
        与new方法一致，不过`default_fold`是可选的
        """
        function PikaParser(
            name::String,
            rules::Dict, 
            grammar::P.Grammar,
            folds::Dict,
            stringify_func::Function;
            default_fold::Function = default_fold,
            preprocess_func::Function = identity, # 默认不作处理
            )
            new(
                name,
                rules,
                grammar,
                folds,
                start,
                default_fold,
                stringify_func,
                preprocess_func,
            )
        end

        """
        内部构造函数：根据语法规则、转换规则、转字符串函数（不然就纯解析）封装Pika
        - 自动构造语法对象

        可选参数：
        - start：决定语法解析起点
        - default_fold：默认转换函数
        """
        function PikaParser(
            name::String,
            rules::Dict, 
            folds::Dict,
            stringify_func::Function;
            start::Symbol = :top,
            default_fold::Function = default_fold,
            preprocess_func::Function = identity, # 默认不作处理
            )
            new(
                name,
                rules,
                P.make_grammar(
                    [start], # 入口(此处限制到只有一个)
                    P.flatten(rules, Char) # 扁平化
                ),
                folds,
                start,
                default_fold,
                stringify_func,
                preprocess_func,
            )
        end

        """
        内部构造函数
        - 自动构造语法对象
        - 自动封装stringify解析器
        """
        @inline function PikaParser(
            name::String,
            rules::Dict, 
            folds::Dict,
            stringify_parser::Conversion.AbstractParser,
            args...; # 提供给「字符串打包器」的额外参数
            start::Symbol = :top,
            default_fold::Function = default_fold,
            preprocess_func::Function = identity, # 默认不作处理
            )
            PikaParser(
                name,
                rules,
                folds,
                object -> Conversion.narsese2data(stringify_parser, object, args...);
                start = start,
                default_fold = default_fold,
                preprocess_func = preprocess_func,
            )
        end

        """
        从字符串解析器中导入
        1. 根据内容自动生成语法
        2. 自动生成转换器
        3. 内联字符串解析器
        4. 跳转到第一个构造函数
        """
        function PikaParser(
            name::String,
            parser::Conversion.StringParser,
            folds::Dict,
            args...; # 提供给「字符串打包器」的额外参数
            start::Symbol = :top,
            default_fold::Function = default_fold,
            )
            # 直接构建解析器
            PikaParser(
                name,
                generate_rule_from_string_parser(
                    parser # 根据内容自动生成语法
                ),
                folds,
                parser,
                args...;
                start = start,
                default_fold = default_fold,
                preprocess_func = parser.preprocess, # 引入字串解析器的预处理函数
            )
        end

    end

    # 字符串显示
    @redirect_SRS parser::PikaParser parser.name

    """
    定义「Pika转换」的「目标类型」
    - 字串↔Narsese对象
    """
    const PIKA_PARSE_TARGETS::Type = JuNarsese.Conversion.DEFAULT_PARSE_TARGETS

    "目标类型：Narsese"
    Conversion.parse_target_types(::PikaParser) = PIKA_PARSE_TARGETS

    "数据类型：扩展的Narsese文本"
    Base.eltype(::PikaParser)::Type = String

    begin "具体转换实现"
        
        "字符串⇒目标对象"
        @inline function JuNarsese.data2narsese(parser::PikaParser, ::Type, narsese::AbstractString)::PIKA_PARSE_TARGETS

            # 预处理
            string::String = parser.preprocess_func(narsese)

            state::P.ParserState = P.parse(parser.grammar, string)

            match::Union{Integer, Nothing} = P.find_match_at!(state, parser.start, 1)
            
            (isnothing(match) || match < 1) && error("$parser: 解析「$narsese($string)」失败！match = $match")

            return P.traverse_match(
                state, match;
                fold = (m, p, s) -> get(
                    parser.folds, m.rule, 
                    parser.default_fold
                )(m.view, s),
            )
        end
        
        "借用字符串解析器"
        @inline function JuNarsese.narsese2data(parser::PikaParser, t::PIKA_PARSE_TARGETS)::String
            return parser.stringify_func(t)
        end

    end


    # 定义 #

    "初代版本α"
    const PikaParser_alpha::PikaParser = PikaParser(
        "PikaParser_alpha",
        NARSESE_RULES_ALPHA,
        NARSESE_DEFAULT_FOLDS,
        Conversion.StringParser_ascii;
        start = :top
    )

    "借用原生字符串解析器"
    const PikaParser_ascii::PikaParser = PikaParser(
        "PikaParser_ascii",
        Conversion.StringParser_ascii,
        NARSESE_DEFAULT_FOLDS;
        start = :top
    )

    "借用原生LaTeX解析器"
    const PikaParser_latex::PikaParser = PikaParser(
        "PikaParser_latex",
        Conversion.StringParser_latex,
        NARSESE_DEFAULT_FOLDS;
        start = :top
    )

    "借用原生漢文解析器"
    const PikaParser_han::PikaParser = PikaParser(
        "PikaParser_han",
        Conversion.StringParser_han,
        NARSESE_DEFAULT_FOLDS;
        start = :top
    )

    "重载「字符串宏の快捷方式」`:pika`⇒`PikaParser_alpha`"
    Conversion.get_parser_from_flag(::Val{:pika})::TAbstractParser = PikaParser_alpha
    Conversion.get_parser_from_flag(::Val{:pika_alpha})::TAbstractParser = PikaParser_alpha
    Conversion.get_parser_from_flag(::Val{:pika_α})::TAbstractParser = PikaParser_alpha
    
    # 重载「字符串宏の快捷方式」`:pika_XXX`⇒`PikaParser_XXX`
    for symbol in (:ascii, :latex, :han)
        Conversion.get_parser_from_flag(::Val{Symbol(:pika_, symbol)})::TAbstractParser = eval(
            Symbol("PikaParser_" * string(symbol))
        )
    end

end
