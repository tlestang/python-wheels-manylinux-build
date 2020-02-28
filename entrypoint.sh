#!/bin/bash
set -e -x

# CLI arguments
PY_VERSIONS=$1
BUILD_REQUIREMENTS=$2
SYSTEM_PACKAGES=$3
PACKAGE_PATH=$4
PIP_WHEEL_ARGS=$5
BUILD_SYSTEM=$6

if [ ! -z "$SYSTEM_PACKAGES" ]; then
    yum install -y ${SYSTEM_PACKAGES}  || { echo "Installing yum package(s) failed."; exit 1; }
fi

cd /github/workspace/"${PACKAGE_PATH}"

# Compile wheels
arrPY_VERSIONS=(${PY_VERSIONS// / })
for PY_VER in "${arrPY_VERSIONS[@]}"; do
    # Update pip
    /opt/python/"${PY_VER}"/bin/pip install --upgrade --no-cache-dir pip

    # Install build requirements, if passed
    if [ ! -z "$BUILD_REQUIREMENTS" ]; then
        /opt/python/"${PY_VER}"/bin/pip install --no-cache-dir ${BUILD_REQUIREMENTS} || { echo "Installing requirements failed."; exit 1; }
    fi

    # Install poetry, if required
    if [ "${BUILD_SYSTEM}" == "poetry" ]; then
        /opt/python/"${PY_VER}"/bin/pip install --no-cache-dir poetry || { echo "Installing poetry failed."; exit 1; }
    fi

    # Build wheels
    if [ "${BUILD_SYSTEM}" == "pip" ]; then
        /opt/python/"${PY_VER}"/bin/pip wheel . -w ./dist ${PIP_WHEEL_ARGS} || { echo "Building wheels failed."; exit 1; }
    elif [ "${BUILD_SYSTEM}" == "poetry" ]; then
        /opt/python/"${PY_VER}"/bin/poetry install || { echo "Installing poetry package failed."; exit 1; }
        /opt/python/"${PY_VER}"/bin/poetry build || { echo "Building wheels failed."; exit 1; }
    else
        echo "Invalid build-system: `${BUILD_SYSTEM}`, use `pip` or `poetry`."; exit 1;
    fi
done

# Bundle external shared libraries into the wheels
for whl in ./dist/*-linux*.whl; do
    auditwheel repair "$whl" --plat "${PLAT}" -w ./dist || { echo "Repairing wheels failed."; auditwheel show "$whl"; exit 1; }
done

echo "Succesfully build wheels:"
ls ./dist
