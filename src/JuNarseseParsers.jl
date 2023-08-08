"""
JuNarseseParsers 入口模块

功能：在JuNarsese的基础上，增加与JSON、字节码、XML的互转支持
"""
module JuNarseseParsers

using JuNarsese
using JuNarsese.Conversion

# 导入待修改符号
import JuNarsese.Conversion: data2narsese, narsese2data

# 导出修改后的符号
export data2narsese, narsese2data

# 导入各个文件 #

# XML
include("parsers/xml.jl")

# JSON
include("parsers/json.jl")

# 序列化
include("parsers/serialization.jl")

end # module
