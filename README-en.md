# JuNarsese Parsers

[简体中文](https://github.com/ARCJ137442/JuNarseseParsers.jl/blob/main/README.md) | **English**

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Static Badge](https://img.shields.io/badge/julia-package?logo=julia&label=1.8%2B)](https://julialang.org/)

[![CI status](https://github.com/ARCJ137442/JuNarseseParsers.jl/workflows/CI/badge.svg)](https://github.com/ARCJ137442/JuNarseseParsers.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/ARCJ137442/JuNarseseParsers.jl/graph/badge.svg?token=3FF26Y3YJG)](https://codecov.io/gh/ARCJ137442/JuNarseseParsers.jl)

This project uses [Semantic Versioning 2.0.0](https://semver.org/) for version management.

## Overview

JuNarseseParsers

1. In string parsers, use multiple grammars to describe Narsese and interface with multiple grammar libraries:
   - [**Lerche**](<https://github.com/jamesrhester/Lerche.jl>)(`LarkParser_alpha`) based on *EBNF*
   - [**PikaParser**](<https://github.com/LCSB-BioCore/PikaParser.jl>) based on *PEG*
     - Overall supports more relaxed Narsese syntax, for example:
       - Function computation form for compound term with operator: `op(x, y)` ([CommonNarsese](https://github.com/ARCJ137442/JuNarsese.jl#commonnarsese): `(*, ^op, x, y)`)
       - 🆕Sentence representation without brackets: `water --> liquid.` ([CommonNarsese](https://github.com/ARCJ137442/JuNarsese.jl#commonnarsese): `<water --> liquid>.`)
     - Multiple parser subtypes:
       - Alpha parser (`PikaParser_alpha`)
         - The first parser built with pure PikaParser rules
         - Syntax compatible with default [CommonNarsese](https://github.com/ARCJ137442/JuNarsese.jl#commonnarsese) parser
         - May contain some latest parser features
           - e.g. arbitrary whitespace delimiters
       - Parsers copied from string parser `StringParser`
         - e.g. `StringParser_ascii` ⇒ `PikaParser_ascii`
2. Extend JuNarsese parsers to support multiple representation forms
   - Based on JuNarsese's built-in "native object parser":
     - **[JSON](https://www.json.org/)** (`JSONParser`): array/object two modes (latter as default)
     - **[XML](https://www.xml.com/)** (`XMLParser`): pure translation/optimized two modes (latter as default)
     - **[S-Expr](https://zh.wikipedia.org/wiki/S-表达式)** (`SExprParser`): Lisp-style expression system
     - **[YAML](https://yaml.org)** (`YAMLParser`): array/object two modes (latter as default)
     - **[TOML](https://toml.io)** (`TOMLParser`): "array" single mode only
   - **Serialization** (`S11nParser`): Interface with Julia's built-in serialization system

## References

- JuNarsese (data structure support): <https://github.com/ARCJ137442/JuNarsese.jl>
- PyNARS (Lark, parser grammar): <https://github.com/bowen-xu/PyNARS>
