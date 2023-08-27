"""
JuNarseseParsers 入口模块

功能：在JuNarsese的基础上，增加与JSON、字节码、XML的互转支持
"""
module JuNarseseParsers

using JuNarsese
using JuNarsese.Util # 共用Util库
using JuNarsese.Conversion

# 导入待修改符号
import JuNarsese.Conversion: data2narsese, narsese2data

# 导出修改后的符号
export data2narsese, narsese2data

# 导入各个文件 #

# XML
include("xml.jl")

# S-表达式
include("s_expr.jl")

# JSON
include("json.jl")

# YAML
include("yaml.jl")

# TOML
include("toml.jl")

# 序列化
include("serialization.jl")

# Lerche(Lark)
include("lark.jl")

# Pika(PikaParser)
include("pika.jl")

end # module
