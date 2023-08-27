(@isdefined JuNarseseParsers) || include("commons.jl") # 已在此中导入JuNarsese、Test

PARSERS::Vector{TAbstractParser} = [
    SExprParser_optimized
    SExprParser_pure
    JSONParser_object
    JSONParser_array
    XMLParser_optimized
    XMLParser_pure
    YAMLParser_dict
    YAMLParser_vector
    TOMLParser
    S11nParser
    PikaParser_alpha
    PikaParser_ascii
    PikaParser_latex
    PikaParser_han
]

for parser in PARSERS
    
    # 目标类型
    @test parse_target_types(parser) isa Type

    # 数据类型
    @test eltype(parser) isa Type

end
