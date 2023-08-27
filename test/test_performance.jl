(@isdefined JuNarseseParsers) || include("commons.jl") # 已在此中导入JuNarsese、Test

all_narsese::Tuple = (test_set.terms..., test_set.sentences...)

for symbol in (:ascii, :latex, :han)
    native = eval(Symbol("StringParser_$symbol"))
    pika = eval(Symbol("PikaParser_$symbol"))
    @info "原生🆚Pika @ $(symbol)：" (@elapsed native.(all_narsese)) (@elapsed pika.(all_narsese))
end
