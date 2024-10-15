# Multi-stage Dockerfile.
ARG UV_VERSION="0.4.20"
ARG PYTHON_VERSION="3.12"
FROM ubuntu:24.10 AS base
ARG PYTHON_VERSION="3.12"
ARG UV_VERSION="0.4.20"

# add venv to path
ENV VIRTUAL_ENV="/app/.venv"
ENV HOST=0.0.0.0
ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH="${VIRTUAL_ENV}/bin:$PATH" \
    PYTHON_VERSION="${PYTHON_VERSION}" \
    UV_PYTHON="${PYTHON_VERSION}" \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONHASHSEED=0 \
    UV_CACHE_DIR="/tmp/.cache/uv/" \
    PIP_CACHE_DIR="/tmp/.cache/pip/" \
    DEBIAN_FRONTEND=noninteractive \
    CI=true

# install packages and setup explicit system-wide python ordering to PYTHON_VERSION_MAJOR
# hadolint ignore=DL3008,DL3013
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=${PIP_CACHE_DIR} \
    --mount=type=cache,target=${UV_CACHE_DIR} \
    apt-get update -o Acquire::CompressionTypes::Order::=gz -q \
    && apt-get upgrade -y -q \
    && apt-get install -y -q \
    --no-install-recommends \
    openssl \
    binutils \
    procps \
    lsb-release \
    software-properties-common \
    tzdata \
    fontconfig \
    locales \
    libgomp1 \
    git \
    curl \
    htop \
    wget \
    build-essential \
    && apt-get update -o Acquire::CompressionTypes::Order::=gz -q \
    && apt-get upgrade -y -q \
    && apt-get clean -yq \
    && apt-get autoclean  -yq \
    && apt-get autoremove --purge -yq \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/archives/*

# UV
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv
ARG UV_VERSION="0.4.20"

# Builder Stage
# so build time dependencies are not included in the final image
# hadolint ignore=DL3006
FROM base AS builder
ARG PYTHON_VERSION="3.12"
ARG UV_VERSION="0.4.20"
ARG PACKAGE_ROOT="."
ARG PACKAGE_NAME="pdm_python"
ARG PACKAGE_REQS="requirements.txt"

# create virtualenv for build in ephemeral stage
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV PYTHONDONTWRITEBYTECODE=0 \
    PYTHONOPTIMIZE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PACKAGE_NAME=${PACKAGE_NAME} \
    PACKAGE_SOURCE="src/${PACKAGE_NAME}" \
    PACKAGE_REQS=${PACKAGE_REQS}

# COPY uv from Source
COPY --from=uv /uv /bin/uv
# minimal copy of files needed to install Dependencies
# COPY package source to build
COPY --link "${PACKAGE_ROOT}/" "/build/"

# install packages to build virtualenv
# hadolint ignore=DL3013
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    --mount=type=cache,target="${UV_CACHE_DIR}" \
    uv venv "${VIRTUAL_ENV}" -p "${PYTHON_VERSION}" --cache-dir "${UV_CACHE_DIR}" --python-preference=system --seed \
    && uv pip install setuptools wheel python-build pdm --compile-bytecode --cache-dir "${UV_CACHE_DIR}" --python-preference=system --link-mode=copy \
    && uv pip install -r "/build/${PACKAGE_REQS}" --compile-bytecode --cache-dir "${UV_CACHE_DIR}" --python-preference=system --link-mode=copy \
    && pdm run

# Common Stage
# hadolint ignore=DL3006
FROM base AS final
ARG PYTHON_VERSION="3.12"
ARG UV_VERSION="0.4.20"
ARG PACKAGE_ROOT="."
ARG PACKAGE_NAME="pdm_python"
ARG PACKAGE_REQS="requirements.txt"
ENV PYTHONDONTWRITEBYTECODE=0 \
    PYTHONOPTIMIZE=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PACKAGE_NAME=${PACKAGE_NAME} \
    PACKAGE_SOURCE="src/${PACKAGE_NAME}" \
    PACKAGE_REQS=${PACKAGE_REQS}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN addgroup --gid 1001 --system app \
    && adduser app --ingroup app --no-create-home --disabled-password --uid 1001 --system

# copy virtual environment from builder stage and transfer ownership to non-root user
COPY --from=builder --chown=app:root --chmod=775 "${VIRTUAL_ENV}" "${VIRTUAL_ENV}"

# copy package source to app
COPY --link --chown=app:root --chmod=775 "${PACKAGE_SOURCE}" /app/

WORKDIR /app

# hadolint ignore=DL3013
# minimal install for source package
ARG APP_ENV=prod
ARG DEBUG=False
ARG LOG_LEVEL=INFO
ARG PORT=8080

ENV APP_ENV=${APP_ENV} \
    DEBUG=${DEBUG} \
    LOG_LEVEL=${LOG_LEVEL} \
    PORT=${PORT}

# Install package & cleanup
# hadolint ignore=DL3013
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    --mount=type=cache,target="${UV_CACHE_DIR}" \
    rm -rf /app/dist /app/build /app/"${PACKAGE_NAME}.egg-info" \
    && uv pip install wheel --no-cache-dir --no-deps .

EXPOSE $PORT
CMD ["/opt/venv/bin/python", "/app/launch.py"]
