# JuNarsese Parsers

**简体中文** | [English](https://github.com/ARCJ137442/JuNarseseParsers.jl/blob/main/README-en.md)

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Static Badge](https://img.shields.io/badge/julia-package?logo=julia&label=1.8%2B)](https://julialang.org/)

[![CI status](https://github.com/ARCJ137442/JuNarseseParsers.jl/workflows/CI/badge.svg)](https://github.com/ARCJ137442/JuNarseseParsers.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ARCJ137442/JuNarseseParsers.jl/graph/badge.svg?token=3FF26Y3YJG)](https://codecov.io/gh/ARCJ137442/JuNarseseParsers.jl)

该项目使用[语义化版本 2.0.0](https://semver.org/)进行版本号管理。

[**JuNarsese**](https://github.com/ARCJ137442/JuNarsese.jl)的解析器**扩展**

## 概述

JuNarseseParsers

1. 在字符串解析器中，使用多种文法描述Narsese，对接多种文法库：
    - 基于 *EBNF* 的[**Lerche**](https://github.com/jamesrhester/Lerche.jl)(`LarkParser_alpha`)
    - 基于 *PEG* 的[**PikaParser**](https://github.com/LCSB-BioCore/PikaParser.jl)
      - 总体上支持更宽松的Narsese语法，例如：
        - 函数计算形式的操作复合词项表示：`op(x, y)`（[CommonNarsese](https://github.com/ARCJ137442/JuNarsese.jl#commonnarsese)：`(*, ^op, x, y)`）
        - 🆕无需陈述括弧的语句表示：`水是流体。`（漢文版本；[CommonNarsese](https://github.com/ARCJ137442/JuNarsese.jl#commonnarsese)：`<水 --> 流体>.`）
      - 多种解析器子类型：
        - Alpha解析器(`PikaParser_alpha`)
          - 第一个使用纯PikaParser规则构建的解析器
          - 语法兼容默认的[CommonNarsese](https://github.com/ARCJ137442/JuNarsese.jl#commonnarsese)解析器
          - 可能包含一些最新的解析器特性
            - 如：任意空白符分割
        - 从字符串解析器`StringParser`中迁移的解析器副本
          - 如「`StringParser_ascii`」⇒「`PikaParser_ascii`」
2. 扩展了JuNarsese的解析器，支持多种表示形式
    - 基于JuNarsese内置的「原生对象解析器」：
      - **[JSON](https://www.json.org/)**(`JSONParser`)：数组/对象 两种模式（后者为默认）
      - **[XML](https://www.xml.com/)**(`XMLParser`)：纯翻译/带优化 两种模式（后者为默认）
      - **[S-Expr](https://zh.wikipedia.org/wiki/S-表达式)**(`SExprParser`)：类Lisp风格的表达式体系
      - **[YAML](https://yaml.org)**(`YAMLParser`)：数组/对象 两种模式（后者为默认）
      - **[TOML](https://toml.io)**(`TOMLParser`)：仅「数组」单一模式
    - **序列化**(`S11nParser`)：对接Julia自带的序列化系统

## 参考

- JuNarsese(数据结构支持): <https://github.com/ARCJ137442/JuNarsese.jl>
- PyNARS(Lark, 解析器文法): <https://github.com/bowen-xu/PyNARS>
