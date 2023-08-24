include("commons.jl") # 已在此中导入JuNarsese、Testbegin "用于「判等失败」后递归查找「不等の元素」的断言函数"

"兜底断言"
recursive_assert(t1::Any, t2::Any) = @assert t1 == t2

"通用复合词项"
recursive_assert(t1::CommonCompound, t2::CommonCompound) = begin
    @assert typeof(t1) == typeof(t2)
    # 【20230820 12:52:34】因为复合词项现采用「预先排序」的方式，现在只需逐个比对
    @assert length(t1) == length(t2)
    for (tt1, tt2) in zip(t1.terms, t2.terms)
        @assert tt1 == tt2 "$tt1 ≠ $tt2 !"
    end
end

"陈述"
recursive_assert(s1::Statement, s2::Statement) = begin
    recursive_assert(s1.ϕ1, s2.ϕ1)
    recursive_assert(s1.ϕ2, s2.ϕ2)
end

"通用测试の宏"
macro equal_test(
parser::Union{Symbol,Expr}, 
test_set::Union{Symbol,Expr},
)
    # quote里的`($parser)`已经自动把内部对象eval了
    quote
        try
            # 词项 #
            # 二次转换
            local converted_terms = ($parser).(($test_set).terms)
            @info "converted_terms@$($parser):"
            join(converted_terms, "\n") |> println
            local reconverted_terms = ($parser).(converted_terms)
            @info "reconverted_terms@$($parser):"
            join(reconverted_terms, "\n") |> println
            # 比对相等
            for (reconv, origin) in zip(reconverted_terms, ($test_set).terms)
                if reconv ≠ origin
                    @error "$($parser): Not eq!" reconv origin
                    # if typeof(reconv) == typeof(origin) <: Statement
                    recursive_assert(reconv, origin)
                end
                @test reconv == origin # 📌【20230806 15:24:11】此处引入额外参数会报错……引用上下文复杂
            end
            # 语句 #
            # 二次转换
            local converted_sentences = ($parser).(($test_set).sentences)
            @info "converted_sentences@$($parser):"
            join(converted_sentences, "\n") |> println
            local reconverted_sentences = ($parser).(converted_sentences)
            @info "converted_sentences@$($parser):" 
            join(converted_sentences, "\n") |> println
            # 比对相等
            for (reconv, origin) in zip(reconverted_sentences, ($test_set).sentences)
                if reconv ≠ origin
                    @error "$($parser): Not eq!" reconv origin
                    dump.([reconv, origin]; maxdepth=typemax(Int))
                end
                @assert reconv == origin # 📌【20230806 15:24:11】此处引入额外参数会报错……引用上下文复杂
            end
            # 任务 #
            # 二次转换
            local converted_tasks = ($parser).(($test_set).tasks)
            @info "converted_tasks@$($parser):"
            join(converted_tasks, "\n") |> println
            local reconverted_tasks = ($parser).(converted_tasks)
            @info "converted_tasks@$($parser):" 
            join(converted_tasks, "\n") |> println
            # 比对相等
            for (reconv, origin) in zip(reconverted_tasks, ($test_set).tasks)
                if reconv ≠ origin
                    @error "$($parser): Not eq!" reconv origin
                    dump.([reconv, origin]; maxdepth=typemax(Int))
                end
                @assert reconv == origin # 📌【20230806 15:24:11】此处引入额外参数会报错……引用上下文复杂
            end
        catch e # 打印堆栈
            Base.printstyled("ERROR: "; color=:red, bold=true)
            Base.showerror(stdout, e)
            Base.show_backtrace(stdout, Base.catch_backtrace())
            rethrow(e)
        end
    end |> esc # 在调用的上下文中解析
end

# 非Test测试：用于堆栈追踪
# @equal_test PikaParser_ascii test_set
# @equal_test PikaParser_latex test_set
# @equal_test PikaParser_han   test_set

# narsese = raw"<A --> B>. :|: %0;0%" # 【20230816 23:50:51】✅
# narsese = raw"<流浪地球 --> 小说>. %1.0;0.5%" # 【20230816 23:50:51】✅
# narsese = raw"<<^A --> #B> ==> <$B --> C>>. :|: %1.0;0.5%" # 【20230816 23:50:51】✅
# narsese = raw"<{SELF} --> [good]>. :|: %0.0;0.5%" # 【20230816 23:50:51】✅
# narsese = raw"<{苹果, 香蕉, 雪梨} --> 水果>. :!0: %1.0;0.9%" # 【20230816 23:51:28】✅
# narsese = raw"(&, A, B)" # 【20230816 23:56:48】✅
# narsese = raw"(&&, <{苹果, 香蕉, 雪梨} --> 水果>, <水果 --> [好吃]>). :!0: %1.0;0.9%" # 【20230817 0:00:15】✅
# narsese = raw"<(*, A, $B, #C, +137) --> ^D>" # 【20230817 0:02:43】✅
# narsese = raw"(/, _, A, B)" # 【20230817 0:07:51】✅
# 【20230817 0:08:06】↓终极挑战：成功✅
# narsese = raw"<<(*, (&|, (&/, <A --> B>, <B --> C>, <C --> D>), (&|, <B --> C>, <C --> D>, <A --> B>), (||, <词项 --> ^操作>, <{A, B, C} --> D>)), (&&, <<[A, B, C] --> D> ==> (||, <A --> D>, <B --> D>, <C --> D>)>, <<(/, R, A, B, _, D) --> C> ==> <(*, A, B, C, D) --> R>>), <(\, A, _, <<(*, ?A, $B) --> ^C> <=> <#D <-> E>>, (-, (&, A, B, C), (|, A, B, C))) --> (/, <<(/, R, A, B, _, D) --> C> ==> <(*, A, B, C, D) --> R>>, _, B, (-, {词项, ?查询变量, #非独变量, ^操作, $独立变量}, [词项, ?查询变量, #非独变量, ^操作, $独立变量]))>, <<<[A, B, C] --> D> ==> (||, <A --> D>, <B --> D>, <C --> D>)> ==> <<(*, ?A, $B) --> ^C> <=> <#D <-> E>>>, (--, <{词项, ?查询变量, #非独变量, ^操作, $独立变量} --> [<(||, (&/, <A --> B>, <B --> C>, <C --> D>), (&|, <B --> C>, <C --> D>, <A --> B>)) ==> <A --> D>>, (&, A, B, C)]>)) --> (-, {词项, ?查询变量, #非独变量, ^操作, $独立变量}, [词项, ?查询变量, #非独变量, ^操作, $独立变量])> <=> <<(||, (&/, <A --> B>, <B --> C>, <C --> D>), (&|, <B --> C>, <C --> D>, <A --> B>)) ==> <A --> D>> ==> (&|, <<A --> B> <|> <B --> C>>, <A --> [B]>, <<B --> C> </> <A --> B>>, <<A --> B> =\> <B --> C>>, <<A --> B> =|> <B --> C>>, <<A --> B> </> <B --> C>>, <<A --> B> =/> <B --> C>>, <{A} --> [B]>, <{A} --> B>)>>. :!2147483647: %0.718281828;0.14159265%"

# @show PikaParser_alpha(narsese)
# @show PikaParser_ascii(narsese)


# XMLParser_optimized.(test_set.terms)
# XMLParser_optimized.(XMLParser_optimized.(test_set.terms))
# XMLParser_pure.(test_set.terms)
# XMLParser_pure.(XMLParser_pure.(test_set.terms))
# JSONParser_object.(test_set.terms)
# JSONParser_object.(JSONParser_object.(test_set.terms))
# JSONParser_array.(test_set.terms)
# JSONParser_array.(JSONParser_array.(test_set.terms))

@testset "JuNarseseParsers" begin

    @testset "SExprParser" begin
        @equal_test SExprParser_optimized test_set
        @equal_test SExprParser_pure test_set
    end

    @testset "JSONParser" begin
        @equal_test JSONParser_object test_set
        @equal_test JSONParser_array test_set
    end

    @testset "XMLParser" begin
        @equal_test XMLParser_optimized test_set
        @equal_test XMLParser_pure test_set
    end

    @testset "YAMLParser" begin
        @equal_test YAMLParser_dict test_set
        @equal_test YAMLParser_vector test_set
    end

    @testset "TOMLParser" begin
        @equal_test TOMLParser test_set # 【20230824 20:21:42】TOML不支持顶层的数组
    end

    @testset "S11nParser" begin
        @equal_test S11nParser test_set # 【20230808 10:46:20】似乎已经解决了「EOF Error」问题
    end

    @testset "LarkParser" begin
        @equal_test LarkParser_alpha test_set
    end

    @testset "PikaParser" begin
        @equal_test PikaParser_alpha test_set
        @equal_test PikaParser_ascii test_set
        @equal_test PikaParser_latex test_set
        @equal_test PikaParser_han   test_set
    end

    # （番外）性能测试

    all_narsese::Tuple = (test_set.terms..., test_set.sentences...)

    for symbol in (:ascii, :latex, :han)
        native = eval(Symbol("StringParser_$symbol"))
        pika = eval(Symbol("PikaParser_$symbol"))
        @info "原生🆚Pika @ $(symbol)：" (@elapsed native.(all_narsese)) (@elapsed pika.(all_narsese))
    end

end
