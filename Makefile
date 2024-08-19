# UNPACK ARGS TO EXCLUDE THE FIRST ARGUMENT
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
PDM := $(shell pdm --version 2>/dev/null)
PYTHON_VERSION := "3.12"

.PHONY: pdm activate install-all upgrade lock setup-hooks pip-export install-prod lint-all tests

pdm:
ifndef PDM
    $(error "PDM is not available please install PDM from 'https://pdm-project.org/en/latest'")
endif


venv:
	@echo "Creating virtual environment"
	@pdm venv create $(PYTHON_VERSION)

activate: pdm
	@echo "Activating virtual environment"
	@eval source .venv/bin/activate

install-all: pdm activate
	@echo "Installing all dependencies"
	@eval pdm install -G:all

upgrade: pdm activate
	@echo "Upgrading pdm and pre-commit"
	@eval pdm self update
	@eval pdm run pre-commit autoupdate
	@eval pdm update -G:all
	@eval pdm export --prod --without-hashes -f requirements -o requirements.txt

lock: pdm activate
	@echo "Locking dependencies"
	@eval pdm lock
	@eval pdm export --prod --without-hashes -f requirements -o requirements.txt

setup-hooks: pdm activate
	@echo "Setting up pre-commit hooks"
	@eval pdm run pre-commit install --install-hooks

pip-export: pdm activate
	@echo "Exporting dependencies"
	@eval pdm export --prod --without-hashes -f requirements -o requirements.txt

install-prod: pdm activate
	@echo "Installing production dependencies"
	@eval pdm install --prod

lint-all: pdm activate setup-hooks
	@echo "Running pre-commit hooks in pre-commit stage"
	@eval SKIP="tests" pdm run pre-commit run --all-files --verbose --hook-stage="pre-commit"
	@eval pyclean .

tests: pdm activate
	@echo "Running tests"
	@eval nox -s tests -- ./tests

# Catch for all targets
%:
	@:
