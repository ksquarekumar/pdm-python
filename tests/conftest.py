from typing import Literal

import pytest


@pytest.fixture(autouse=True, scope="session")
def distribution_name() -> Literal["pdm_python"]:
    return "pdm_python"


@pytest.fixture(autouse=True, scope="session")
def distribution_version(distribution_name: Literal["pdm_python"]) -> str:
    from importlib_metadata import version

    return version(distribution_name=distribution_name)
