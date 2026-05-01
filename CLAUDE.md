# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repository Is

This is a **GitBook documentation repository** for [RetractorDB](https://github.com/michalwidera/retractordb), an Edge Signal Processing Engine (ESPE) for real-time regular time series data. All content is written in **Polish**. There is no source code, build system, or test suite — the workflow is: edit Markdown → commit → GitBook auto-publishes.

The table of contents is defined in [SUMMARY.md](SUMMARY.md). Images and assets live in [.gitbook/assets/](.gitbook/assets/).

## RetractorDB Architecture (Documentation Subject)

RetractorDB has three executables:

- **xretractor** — singleton main processor; compiles RQL queries, builds execution plans, manages shared memory for IPC
- **xqry** — multi-instance client; queries the running xretractor, sends data/commands, supports output formats: raw, Graphite, InfluxDB, Gnuplot
- **xtrdb** — binary artifact analysis tool with optional interactive mode

**Data flow:**
```
Input sources → xretractor (compile + execute) → shared memory → xqry clients
                       ↓
              Artifact files (binary/text) → xtrdb (analysis)
```

**Three stream types:**
- **Ephemerydy** (Ephemerides) — volatile input streams that cannot be stored
- **Substraty** (Substrates) — intermediate computed streams
- **Artefakty** (Artifacts) — materialized, persisted results

## Query Language (RQL)

RQL is based on **time-series algebra** (not relational algebra). Key commands:
- `DECLARE` — declares data sources and their types
- `SELECT` — defines transformation/aggregation over time windows
- `RULE` — defines alerting conditions

The compiler uses an ANTLR4-based parser. Query compilation involves symbol expansion, aliasing, `_` symbol processing, type unification, and dependency tree construction — each step documented in [kompilacja-zapytan/](kompilacja-zapytan/).

## Mathematical Foundations

The algebra underlying RQL is built on **Beatty sequences** and the **Fraenkel theorem** (non-homogeneous Beatty sequences). The sliding window mechanism (AGSE — Algorytm Generowania Serii Epizodów) is the core execution primitive. This theory is documented in [podstawy-matematyczne/](podstawy-matematyczne/).
