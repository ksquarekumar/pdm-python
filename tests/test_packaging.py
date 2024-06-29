from importlib_metadata import version


def test_version(distribution_name: str, distribution_version: str) -> None:
    assert version(distribution_name) == distribution_version
