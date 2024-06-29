"""Nox sessions."""

import os
from pathlib import Path
import shlex
from textwrap import dedent
import time

from joblib import cpu_count
import nox
from nox import session
from nox.sessions import Session
import requests


package: str = "pdm_python"
python_versions: list[str] = ["3.11"]

PDM_ARGS: list[str] = ["pdm", "run"]

nox.needs_version = ">= 2024.3.2"

PROJECT_ROOT_PATH: Path = Path(__file__).resolve().absolute().parent

nox.options.envdir = str(os.getenv("VIRTUAL_ENV", f"{PROJECT_ROOT_PATH!r}/.venv"))

nox.options.reuse_existing_virtualenvs = True

nox.options.sessions = (
    "mypy",
    "black",
    "ruff",
    "notebook_format",
    "notebook_lint",
    "precommit",
    "ochrona",
    "tests",
    "coverage",
)


def set_hook_dir(headers: dict[str, str], bindirs: list[str]) -> None:
    """Set the hook directory for pre-commit.

    Parameters
    ----------
        headers (dict[str, str]): mapping of executable to environment
        bindirs (list[str]): list of paths for python executables

    Returns
    -------
        None
    """
    hookdir: Path = Path(".git") / "hooks"

    if not hookdir.is_dir():
        return

    for hook in hookdir.iterdir():
        if hook.name.endswith(".sample") or not hook.is_file():
            continue

        if not hook.read_bytes().startswith(b"#!"):
            continue

        text: str = hook.read_text()

        if not any(
            Path("A") == Path("a") and bindir.lower() in text.lower() or bindir in text
            for bindir in bindirs
        ):
            continue

        lines: list[str] = text.splitlines()

        for executable, header in headers.items():
            if executable in lines[0].lower():
                lines.insert(1, dedent(header))
                hook.write_text("\n".join(lines))
                break


def activate_virtualenv_in_precommit_hooks(session: Session) -> None:
    """Activate virtualenv in hooks installed by pre-commit.

    This function patches git hooks installed by pre-commit to activate the
    session's virtual environment. This allows pre-commit to locate hooks in
    that environment when invoked from git.

    Parameters
    ----------
        session: The Session object.

    Returns
    -------
        None
    """
    _session_binary: str = ""

    try:
        _session_binary = getattr(session, "bin")  # noqa: B009
    except ValueError:
        _session_binary = f'{session.env.get("VIRTUAL_ENV")}/bin/python'

    # Only patch hooks containing a reference to this session's bindir. Support
    # quoting rules for Python and bash, but strip the outermost quotes, so we
    # can detect paths within the bindir, like <bindir>/python.
    bindirs: list[str] = [
        bindir[1:-1] if bindir[0] in "'\"" else bindir
        for bindir in (_session_binary, shlex.quote(_session_binary))
    ]

    virtualenv: str | None = session.env.get("VIRTUAL_ENV")
    if virtualenv is None:
        return None

    headers: dict[str, str] = {
        # pre-commit >= 2.16.0
        "python": f"""\
            import os
            os.environ["VIRTUAL_ENV"] = {virtualenv!r}
            os.environ["PATH"] = os.pathsep.join((
                {_session_binary!r},
                os.environ.get("PATH", ""),
            ))
            """,
        # pre-commit >= 2.16.0
        "bash": f"""\
            VIRTUAL_ENV={shlex.quote(virtualenv)}
            PATH={shlex.quote(_session_binary)}"{os.pathsep}$PATH"
            """,
        # pre-commit >= 2.17.0 on Windows forces sh shebang
        "/bin/sh": f"""\
            VIRTUAL_ENV={shlex.quote(virtualenv)}
            PATH={shlex.quote(_session_binary)}"{os.pathsep}$PATH"
            """,
    }

    return set_hook_dir(headers, bindirs)


def validate_path_posargs(*args: str, empty_allowed: bool = False) -> bool:
    """Validate path posargs."""
    posargs: list[str] = [arg for arg in args if not arg.startswith("--")]

    if empty_allowed and (not posargs or len(posargs) == 0):
        msg: str = "Please provide at least one file or directory as an argument"
        raise ValueError(msg)

    for arg in posargs:
        if not Path(arg).resolve().relative_to(PROJECT_ROOT_PATH).exists():
            msg = f"Path {arg} does not exist, args can only be a file or a directory"
            raise ValueError(msg)

    return True


@session(python=False)
def black(session: Session) -> None:
    """Run black."""
    args: list[str] = ["-t", "py311"]

    validate_path_posargs(*session.posargs, empty_allowed=False)

    session.run(*PDM_ARGS, "black", *(args + session.posargs))


@session(python=False)
def ruff(session: Session) -> None:
    """Run ruff."""
    args: list[str] = ["check", "--diff", "--fix"]

    validate_path_posargs(*session.posargs, empty_allowed=False)

    session.run(*PDM_ARGS, "ruff", *(args + session.posargs))


@session(python=False)
def mypy(session: Session) -> None:
    """Run mypy."""
    args: list[str] = [
        "--show-error-codes",
        "--pretty",
    ]

    validate_path_posargs(*session.posargs, empty_allowed=False)
    session.log(f"Received session.posargs: {session.posargs}")

    for arg in session.posargs:
        temp_args: list[str] = []
        parsed_path = (
            (Path(arg).resolve()).relative_to(PROJECT_ROOT_PATH).resolve().absolute()
        )
        if parsed_path.is_dir():
            temp_args = [*args, arg]
            session.run(
                *PDM_ARGS, "mypy", *temp_args, env={"MYPYPATH": f"{PROJECT_ROOT_PATH}"}
            )
        if parsed_path.is_file():
            temp_args = [*args, "--explicit-package-bases", arg]
            session.run(
                *PDM_ARGS, "mypy", *temp_args, env={"MYPYPATH": str(parsed_path.parent)}
            )

        del temp_args


@session(python=False)
def notebook_format(session: Session) -> None:
    """Run Black for notebooks."""
    session.install("nbqa[toolchain]")

    args: list[str] = ["--check", "--diff"]

    validate_path_posargs(*session.posargs, empty_allowed=False)

    session.run(*PDM_ARGS, "nbqa", "black", *(args + session.posargs))


@session(python=False)
def notebook_lint(session: Session) -> None:
    """Run ruff for notebooks."""
    session.install("nbqa[toolchain]")

    args: list[str] = ["--check"]

    validate_path_posargs(*session.posargs, empty_allowed=False)

    session.run(*PDM_ARGS, "nbqa", "ruff", *(args + session.posargs))


@session(python=False)
def ochrona(session: Session) -> None:
    """Scan dependencies for insecure packages with ochrona."""
    from pathlib import Path

    import yaml

    data = yaml.safe_load((Path.cwd() / ".ochrona.yml").read_text())
    reports_directory = Path.cwd() / data["report_location"]

    if not reports_directory.resolve().exists():
        session.log(f"Creating reports directory at {reports_directory}")
        reports_directory.mkdir(
            parents=True,
            if_exists=False,
            mode=0o755,
        )
    else:
        session.log(f"Found reports directory at {reports_directory}")

    session.run(*PDM_ARGS, "ochrona", *session.posargs)


@session(name="pre-commit", python=False)
def precommit(session: Session) -> None:
    """Lint using pre-commit."""
    args: list[str] = session.posargs or [
        "run",
        "--all-files",
        "--hook-stage=pre-commit",
    ]

    if args and args[0] == "install":
        activate_virtualenv_in_precommit_hooks(session)
    # we don't want tests to run in pre-commit in CI, or whenever
    # `pre-commit` itself is invoked from nox, else pre-commit will run tests and take a long time
    # instead, we run tests in the `tests` session and `pre-commit` session is only for linting/static analysis
    session.run(*PDM_ARGS, "pre-commit", *args, env={"SKIP": "tests"})


def poll_local_service_for_readiness(
    session: Session,
    local_service_url: str,
    max_startup_lag: float | None = None,
    request_timeout: int | None = None,
) -> None:
    """Poll ml-flow service for readiness."""
    counter, start = 0, time.time()
    max_startup_lag = max_startup_lag or float(
        os.getenv("LOCAL_SERVICE_MAX_STARTUP_LAG", "30.0")
    )
    request_timeout = request_timeout or int(os.getenv("LOCAL_SERVICE_TIMEOUT", "30"))
    session.log(
        f"Waiting for LOCAL service to start at {local_service_url} with a max_startup_lag of {max_startup_lag}s"
    )
    if local_service_url == "":
        error_message: str = "LOCAL_SERVICE_URL is empty, exiting with error.."
        error: BaseException = OSError(error_message)
        session.log(error_message)
        session.error(error)
    while True:
        time.sleep(2**counter)
        try:
            if (
                requests.get(
                    f"{local_service_url}/health",
                    stream=True,
                    verify=False,  # noqa: S501
                    timeout=request_timeout,
                ).status_code
                == 200
            ):
                return
        except requests.exceptions.ConnectionError:
            pass
        time_elapsed: float = float(time.time() - start)
        session.log(
            f"Waiting for LOCAL service to start (attempt #{counter+1}), time_elapsed: {time_elapsed:.2f}s",
        )
        if time_elapsed > max_startup_lag:
            error_message = f"LOCAL service could not be ready after {max_startup_lag} seconds, exiting with error.."
            error = ResourceWarning(error_message)
            session.log(error_message)
            session.error(error)
        counter += 1


@session(python=False)
def tests(session: Session) -> None:
    """Run the test suite."""
    from dotenv import dotenv_values

    env_args = {
        k: (v or "")
        for k, v in dotenv_values(
            (Path.cwd() / ".test.env").resolve(), verbose=True
        ).items()
    }

    validate_path_posargs(*session.posargs, empty_allowed=True)

    docker_build_args: list[str] = ["docker", "compose", "build"]
    docker_up_args: list[str] = ["docker", "compose", "up", "-d"]
    docker_down_args: list[str] = ["docker", "compose", "down", "-v"]
    args: list[str] = [
        "run",
        "--parallel",
        "-m",
        "pytest",
        "--cache-clear",
        "--randomly-seed=42",
        "-n",
        # should be fine as we are i/o bound
        str(cpu_count() + 1),
        "--dist",
        # we run xdist in loadscope if individual tests within modules have shared session-scoped dependencies
        # so we run tests with modules as parallel, assuming a shared & co-dependent session-scope exists at the module level at-least
        "loadscope",
    ]
    try:
        session.run(*docker_build_args, env=env_args)
        session.run(*docker_up_args, env=env_args)
        poll_local_service_for_readiness(
            session=session, local_service_url=env_args["LOCAL_SERVICE_URL"]
        )
        # tests don't need env and should be self-contained
        session.run(*PDM_ARGS, "coverage", *args, *session.posargs)
    except KeyError as err:
        error_message = f"Missing environment variable: {err} in env"
        session.log(error_message)
        session.error(err)
    finally:
        # shutdown gracefully in local development flows, but immediately in `CI`
        session.run(
            *PDM_ARGS,
            *docker_down_args,
            terminate_timeout=(
                float("inf") if env_args.get("CI", "false") == "false" else 0.0
            ),
        )
        if session.interactive:
            session.notify("coverage", posargs=[])


@session(python=False)
def coverage(session: Session) -> None:
    """Produce the coverage report."""
    args: list[str] = session.posargs or ["xml", "-i"]

    if not session.posargs and any(Path().glob(".coverage.*")):
        session.run(*PDM_ARGS, "coverage", "combine")

    if "html" in args and not Path.is_dir(Path.cwd() / ".htmlcov"):
        session.warn(
            f"Expected to find coverage directory at {Path.cwd() / '.htmlcov'}, creating one now"
        )
        Path.mkdir(Path.cwd() / ".htmlcov")

    session.run(*PDM_ARGS, "coverage", *args)
