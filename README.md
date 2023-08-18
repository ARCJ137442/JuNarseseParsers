# JuNarsese Parsers

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)

[**JuNarsese**](https://github.com/ARCJ137442/JuNarsese.jl)的解析器**扩展**

## 概述

JuNarseseParsers

1. 扩展了JuNarsese的解析器，支持多种表示形式
    - 基于JuNarsese核心的AST：
      - **JSON**：数组/对象 两种模式（后者为默认）
      - **XML**：纯翻译/带优化 两种模式（后者为默认）
    - **序列化**：对接Julia自带的序列化系统
2. 在字符串解析器中，使用多种文法描述Narsese，对接多种外部解析器：
    - 基于EBNF文法的[Lerche](https://github.com/jamesrhester/Lerche.jl)
    - 基于PEG文法的[PikaParser](https://github.com/LCSB-BioCore/PikaParser.jl)
3. （相应地）使JuNarsese更轻量化、可扩展
    - 后者不再依赖`JSON`、`XML`、`Serialization`库

## 参考

- JuNarsese(数据结构支持): <https://github.com/ARCJ137442/JuNarsese.jl>
- PyNARS(Lark, 解析器文法): <https://github.com/bowen-xu/PyNARS>
