# Multi-stage Dockerfile.
ARG PYTHON_VERSION_MAJOR=3.11
ARG PYTHON_VERSION_MINOR=9
ARG DEBIAN_SOURCE="slim-bookworm"
# Base Image & Stage
FROM python:"${PYTHON_VERSION_MAJOR}.${PYTHON_VERSION_MINOR}-${DEBIAN_SOURCE}" AS base
ARG PYTHON_VERSION_MAJOR=3.11
ARG PYTHON_VERSION_MINOR=9

# add venv to path
ENV VIRTUAL_ENV="/opt/venv"
ENV HOST 0.0.0.0
ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHON_VERSION_MAJOR=${PYTHON_VERSION_MAJOR} \
    PYTHON_VERSION_MINOR=${PYTHON_VERSION_MINOR} \
    PATH="${VIRTUAL_ENV}/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_CACHE_DIR="/tmp/.cache/pip/" \
    DEBIAN_FRONTEND=noninteractive

# install packages and setup explicit system-wide python ordering to PYTHON_VERSION_MAJOR
# hadolint ignore=DL3008,DL3013
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=${PIP_CACHE_DIR} \
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
    && rm -rf /var/cache/apt/archives/* \
    && update-alternatives --install /usr/bin/python python "/usr/local/bin/python${PYTHON_VERSION_MAJOR}" 999 \
    && update-alternatives --install /usr/bin/python3 python3 "/usr/local/bin/python${PYTHON_VERSION_MAJOR}" 999 \
    && update-alternatives --install /usr/bin/pip pip "/usr/local/bin/pip${PYTHON_VERSION_MAJOR}" 999 \
    && update-alternatives --install /usr/bin/pip3 pip3 "/usr/local/bin/pip${PYTHON_VERSION_MAJOR}" 999 \
    && python -m pip install --no-cache-dir --upgrade pip virtualenv wheel setuptools python-build

# Builder Stage
# so build time dependencies are not included in the final image
# hadolint ignore=DL3006
FROM base AS builder

# create virtualenv for build in ephemeral stage
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV PYTHONDONTWRITEBYTECODE=0 \
    PYTHONOPTIMIZE=1

# hadolint ignore=DL3008
RUN "usr/local/bin/python${PYTHON_VERSION_MAJOR}" -m venv "${VIRTUAL_ENV}"

# minimal copy of files needed to install Dependencies
ARG PACKAGE_ROOT="."
ARG PACKAGE_REQS="requirements.txt"

COPY --link "${PACKAGE_SOURCE}/" "/build/"

# install packages to build virtualenv
# hadolint ignore=DL3013
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    /opt/venv/bin/pip install --no-cache-dir --use-pep517 -r "/build/${PACKAGE_REQS}"

# Common Stage
# hadolint ignore=DL3006
FROM base AS final

RUN addgroup --gid 1001 --system app \
    && adduser app --ingroup app --no-create-home --disabled-password --uid 1001 --system

# copy virtual environment from builder stage and transfer ownership to non-root userdoc
COPY --from=builder --chown=app:root --chmod=775 "${VIRTUAL_ENV}" "${VIRTUAL_ENV}"

# copy and install source package
ARG PACKAGE_ROOT="."
ARG PACKAGE_NAME="pdm_python"

COPY --link --chown=app:root --chmod=775 "${PACKAGE_SOURCE}" /code/

WORKDIR /code

# hadolint ignore=DL3013
# minimal install for source package
ARG APP_STAGE=prod
ARG DEBUG=False
ARG LOG_LEVEL=INFO
ARG PORT=8080

ENV APP_STAGE=${APP_STAGE} \
    DEBUG=${DEBUG} \
    LOG_LEVEL=${LOG_LEVEL} \
    PORT=${PORT}

# Install package & cleanup
# hadolint ignore=DL3013
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    rm -rf /code/dist /code/build /code/"${PACKAGE_NAME}.egg-info" \
    && /opt/venv/bin/python -m pip install wheel --no-cache-dir --no-deps .

EXPOSE $PORT
CMD ["/opt/venv/bin/python", "/code/launch.py"]
