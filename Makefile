# UNPACK ARGS TO EXCLUDE THE FIRST ARGUMENT
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
SHELL := $(shell which zsh >/dev/null 2>&1 && echo /bin/zsh || echo /bin/bash)
PYTHON_VERSION := "3.12"

.PHONY: uv venv-exists install-tools upgrade-tools venv activate setup-hooks install-all upgrade lock export_deps install-prod lint-all tests

VIRTUAL_ENV := "./.venv"
VIRTUAL_ENV_ACTIVATE := "$(VIRTUAL_ENV)/bin/activate"
PYTHON := "$(VIRTUAL_ENV)/bin/python"
PDM := $(shell pdm --version 2>/dev/null)
UV := $(shell uv --version 2>/dev/null)

uv:
ifndef UV
    $(error "UV is not available please install UV from 'https://github.com/astral-sh/uv'")
endif

pdm: uv
ifndef PDM
    $(warning "PDM is not available. Please install PDM using `make install-tools`")
endif

venv-exists:
	@if [ -d ".venv" ]; then \
		echo "Virtual environment already exists!"; \
		exit 1; \
	fi

install-tools: uv
	@echo "Installing tools"
	@eval uv tool install pdm
	@eval uv tool install ruff
	@eval uv tool install mypy
	@eval uv tool install pyright
	@eval uv tool install pre-commit
	@eval uv tool install pre-commit-hooks
	@eval uv tool install codespell
	@eval uv tool install pyclean
	@eval uv tool install detect-secrets
	@eval uv tool install ochrona
	@eval uv tool install nox
	@eval uv tool install codespell
	@eval uv tool update-shell

upgrade-tools: uv
	@echo "Upgrading tools"
	@eval uv self update
	@eval uv tool update --all

venv: venv-exists
	@echo "Creating virtual environment"
	@pdm venv create --with-pip $(PYTHON_VERSION)

activate: VIRTUAL_ENV_ACTIVATE
	@echo "Activated virtual environment, using $$(${PYTHON} -V) from ${PYTHON}"

setup-hooks: pdm activate
	@echo "Setting up pre-commit hooks"
	@eval pdm run pre-commit install --install-hooks

install-all: uv pdm activate
	@echo "Installing all dependencies"
	@eval pdm install -G:all
	@eval pdm run pre-commit install --install-hooks

upgrade-all: uv pdm activate
	@echo "Upgrading pre-commit and project-dependencies"
	@eval pdm run pre-commit autoupdate
	@eval pdm update -G:all
	@eval pdm run pre-commit install --install-hooks

lock: uv pdm activate
	@echo "Locking dependencies"
	@eval rm -rf pdm.lock
	@eval pdm run lock
	@eval uv lock

export_deps: uv pdm activate
	@echo "Exporting dependencies to requirements.txt"
	@eval pdm run export

install-prod: uv pdm activate
	@echo "Installing production dependencies"
	@eval pdm install --prod --with all

lint-all: uv pdm activate setup-hooks
	@echo "Running pre-commit hooks in pre-commit stage"
	@eval pdm run lint
	@eval pyclean .

tests: uv pdm activate
	@echo "Running tests"
	@eval pdm run tests
	@eval pdm run container_tests

# Catch for all targets
%:
	@:
