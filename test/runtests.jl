include("commons.jl") # 已在此中导入JuNarsese、Test

# 通用测试の宏
macro equal_test(
    parser::Union{Symbol,Expr}, 
    test_set::Union{Symbol,Expr},
    )
    # quote里的`($parser)`已经自动把内部对象eval了
    quote
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
                @error "Not eq!" reconv origin
                dump.(($parser).([reconv, origin]); maxdepth=typemax(Int))
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
                @error "$parser: Not eq!" reconv origin
                dump.(($parser).([reconv, origin]); maxdepth=typemax(Int))
            end
            @test reconv == origin # 📌【20230806 15:24:11】此处引入额外参数会报错……引用上下文复杂
        end
    end |> esc # 在调用的上下文中解析
end

# 非Test测试：用于堆栈追踪
@equal_test LarkParser_alpha test_set

# XMLParser_optimized.(test_set.terms)
# XMLParser_optimized.(XMLParser_optimized.(test_set.terms))
# XMLParser_pure.(test_set.terms)
# XMLParser_pure.(XMLParser_pure.(test_set.terms))
# JSONParser_object.(test_set.terms)
# JSONParser_object.(JSONParser_object.(test_set.terms))
# JSONParser_array.(test_set.terms)
# JSONParser_array.(JSONParser_array.(test_set.terms))

@testset "JuNarseseParsers" begin

    @testset "XMLParser" begin
        @equal_test XMLParser_optimized test_set
        @equal_test XMLParser_pure test_set
    end

    @testset "JSONParser" begin
        @equal_test JSONParser_object test_set
        @equal_test JSONParser_array test_set
    end

    @testset "S11nParser" begin
        @equal_test S11nParser test_set # 【20230808 10:46:20】似乎已经解决了「EOF Error」问题
    end

    @testset "LarkParser" begin
        @equal_test LarkParser_alpha test_set
    end
end
