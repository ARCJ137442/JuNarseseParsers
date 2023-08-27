(@isdefined JuNarseseParsers) || include("commons.jl") # 已在此中导入JuNarsese、Test

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
