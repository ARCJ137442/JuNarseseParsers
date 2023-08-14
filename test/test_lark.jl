if !isdefined(Main, :JuNarsese)
    push!(LOAD_PATH, "../src") # 用于直接打开（..上一级目录）
    push!(LOAD_PATH, "../../JuNarsese/") # 用于直接打开（..上一级目录）
    push!(LOAD_PATH, "src") # 用于VSCode调试（项目根目录起）
    push!(LOAD_PATH, "../JuNarsese/") # 用于VSCode调试（项目根目录起）

    # 自动导入JuNarsese模块
    using JuNarseseParsers
end

include("../src/parsers/lark.jl")



narsese_parser = Lark(
    NARSESE_GRAMMAR;
    # parser = "lalr",
    lexer="standard", 
#     transformer=NarseseTransformer(),
)

narsese_transformer = NarseseTransformer()

parse_nse = s -> Lerche.parse(narsese_parser, s)

tree_1 = raw"<<^A --> #B> ==> <$B --> C>>. :|:" |> parse_nse # 【20230814 23:34:38】就是不能插真值：bug@「 %1.0;0.9%」「Unexpected token 1 at line 1, column 36.」
@show tree_1
@show Lerche.transform(narsese_transformer, tree_1)

tree_2 = raw"<<(*, (&|, (&/, <A --> B>, <B --> C>, <C --> D>), (&|, <B --> C>, <C --> D>, <A --> B>), (||, <词项 --> ^操作>, <{A, B, C} --> D>)), (&&, <<[A, B, C] --> D> ==> (||, <A --> D>, <B --> D>, <C --> D>)>, <<(/, R, A, B, _, D) --> C> ==> <(*, A, B, C, D) --> R>>), <(\, A, _, <<(*, ?A, $B) --> ^C> <=> <#D <-> E>>, (-, (&, A, B, C), (|, A, B, C))) --> (/, <<(/, R, A, B, _, D) --> C> ==> <(*, A, B, C, D) --> R>>, _, B, (-, {词项, ?查询变量, #非独变量, ^操作, $独立变量}, [词项, ?查询变量, #非独变量, ^操作, $独立变量]))>, <<<[A, B, C] --> D> ==> (||, <A --> D>, <B --> D>, <C --> D>)> ==> <<(*, ?A, $B) --> ^C> <=> <#D <-> E>>>, (--, <{词项, ?查询变量, #非独变量, ^操作, $独立变量} --> [<(||, (&/, <A --> B>, <B --> C>, <C --> D>), (&|, <B --> C>, <C --> D>, <A --> B>)) ==> <A --> D>>, (&, A, B, C)]>)) --> (-, {词项, ?查询变量, #非独变量, ^操作, $独立变量}, [词项, ?查询变量, #非独变量, ^操作, $独立变量])> <=> <<(||, (&/, <A --> B>, <B --> C>, <C --> D>), (&|, <B --> C>, <C --> D>, <A --> B>)) ==> <A --> D>> ==> (&|, <<A --> B> <|> <B --> C>>, <A --> [B]>, <<B --> C> </> <A --> B>>, <<A --> B> =\> <B --> C>>, <<A --> B> =|> <B --> C>>, <<A --> B> </> <B --> C>>, <<A --> B> =/> <B --> C>>, <{A} --> [B]>, <{A} --> B>)>>." |> parse_nse
# @show tree_2

@show Lerche.transform(narsese_transformer, tree_2)

