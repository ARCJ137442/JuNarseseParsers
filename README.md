# JuNarsese Parsers

[**JuNarsese**](https://github.com/ARCJ137442/JuNarsese.jl)的解析器**扩展**

## 概述

JuNarseseParsers

1. 扩展了JuNarsese的解析器，支持多种表示形式
    - 基于JuNarsese核心的AST：
      - **JSON**：数组/对象 两种模式（后者为默认）
      - **XML**：纯翻译/带优化 两种模式（后者为默认）
    - **序列化**：对接Julia自带的序列化系统
2. （相应地）使JuNarsese更轻量化、可扩展
    - 后者不再依赖`JSON`、`XML`、`Serialization`库
