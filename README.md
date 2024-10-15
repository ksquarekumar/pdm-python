[![tests](https://github.com/ksquarekumar/pdm-python/workflows/Tests/badge.svg)][tests]

[![styling](https://img.shields.io/badge/code%20style-black-000000.svg)][black]
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)][pre-commit]
[![static-analysis](https://www.mypy-lang.org/static/mypy_badge.svg)][mypy]
[![pdm-managed](https://img.shields.io/badge/pdm-managed-blueviolet)][pdm]
[![linting](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)][ruff]
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)][uv]

[tests]: https://github.com/ksquarekumar/pdm-python/actions?workflow=Tests
[pre-commit]: https://github.com/pre-commit/pre-commit
[black]: https://github.com/psf/black
[ruff]: https://github.com/astral-sh/ruff
[mypy]: https://github.com/python/mypy
[pdm]: https://pdm-project.org
[uv]: https://github.com/astral-sh/uv

# README

A Simple Project meant to be forked and used as a template for creating new Python Packages

## Installation

```shell
make install-tools # Installs global tools with `uv`
make venv # Creates a virtual environment
make install-all # Installs all dependencies and setup pre-commit hooks
```

## Updating Project & Dependencies

```shell
make upgrade-tools # Upgrades the global tools with `uv`
make upgrade # Upgrades the project and dependencies
make lock # Updates the project dependencies only
```

## Updating Project Dependencies Only

```shell
make lock # Updates the project dependencies only
```

## Exporting Dependencies

```shell
make export_deps # Exports the dependencies to requirements.txt
```

## Linting

```shell
make lint-all # Runs all linters
```

## Running Tests

```shell
make tests # Runs all tests
```
