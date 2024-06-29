[![tests](https://github.com/ksquarekumar/pdm-python/workflows/Tests/badge.svg)][tests]

[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)][pre-commit]
[![styling](https://img.shields.io/badge/code%20style-black-000000.svg)][black]
[![linting](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/ruff/main/assets/badge/v2.json)][ruff]
[![static-analysis](https://www.mypy-lang.org/static/mypy_badge.svg)][mypy]
[![pdm-managed](https://img.shields.io/badge/pdm-managed-blueviolet)][pdm]

[tests]: https://github.com/ksquarekumar/pdm-python/actions?workflow=Tests
[pre-commit]: https://github.com/pre-commit/pre-commit
[black]: https://github.com/psf/black
[ruff]: https://github.com/astral-sh/ruff
[mypy]: https://github.com/python/mypy
[pdm]: https://pdm-project.org

# README

## Installation

```shell
make install-all
make setup-hooks
```

## Updating Project & Dependencies

```shell
make upgrade
```

## Updating Requirements Only

```shell
make export
```

## Updating Project Dependencies Only

```shell
make lock
```

## Linting

```shell
make lint-all
```

## Running Tests

```shell
make tests
```
