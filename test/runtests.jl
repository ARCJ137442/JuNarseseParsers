(@isdefined JuNarseseParsers) || include("commons.jl") # 已在此中导入JuNarsese、Test

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

    include("test_parsers.jl")

    include("test_conversion.jl")

end
