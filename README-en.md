# JuNarsese Parsers

[简体中文](https://github.com/ARCJ137442/JuNarseseParsers.jl/blob/main/README.md) | **English**

[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)
[![Static Badge](https://img.shields.io/badge/julia-package?logo=julia&label=1.8%2B)](https://julialang.org/)
[![codecov](https://codecov.io/gh/ARCJ137442/JuNarseseParsers.jl/graph/badge.svg?token=3FF26Y3YJG)](https://codecov.io/gh/ARCJ137442/JuNarseseParsers.jl)

This project uses [Semantic Versioning 2.0.0](https://semver.org/) for version management.

## Overview

JuNarseseParsers

1. Extends JuNarsese's parser to support multiple representation formats
    - Based on JuNarsese's built-in "native object parser":
      - **[JSON](https://www.json.org/)**: two modes - array/object (the latter is default)
      - **[XML](https://www.xml.com/)**: two modes - pure translation/optimized (the latter is default)
      - **[S-Expr](https://en.wikipedia.org/wiki/S-expression)**: Lisp-style expression system
      - **[YAML](https://yaml.org)**: two modes - array/object (the latter is default)
      - **[TOML](https://toml.io)**: single mode - "array" only
    - Serialization: interfaces with Julia's built-in serialization system
2. In the string parser, uses multiple grammars to describe Narsese and interfaces with multiple external parsers:
    - Based on EBNF grammar: [Lerche](https://github.com/jamesrhester/Lerche.jl)
    - Based on PEG grammar: [PikaParser](https://github.com/LCSB-BioCore/PikaParser.jl)
3. (Correspondingly) makes JuNarsese more lightweight and extensible
    - The latter no longer depends on the `JSON`, `XML`, or `Serialization` libraries

## References

- JuNarsese (data structure support): <https://github.com/ARCJ137442/JuNarsese.jl>
- PyNARS (Lark, parser grammar): <https://github.com/bowen-xu/PyNARS>
