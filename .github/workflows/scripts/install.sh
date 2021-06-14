#!/usr/bin/env bash

# WARNING: DO NOT EDIT!
#
# This file was generated by plugin_template, and is managed by it. Please use
# './plugin-template --github pulp_2to3_migration' to update this file.
#
# For more info visit https://github.com/pulp/plugin_template

# make sure this script runs at the repo root
cd "$(dirname "$(realpath -e "$0")")"/../../..
REPO_ROOT="$PWD"

set -euv

source .github/workflows/scripts/utils.sh

if [ "${GITHUB_REF##refs/tags/}" = "${GITHUB_REF}" ]
then
  TAG_BUILD=0
else
  TAG_BUILD=1
fi

if [[ "$TEST" = "docs" || "$TEST" = "publish" ]]; then
  pip install -r ../pulpcore/doc_requirements.txt
  pip install -r doc_requirements.txt
fi

pip install -r functest_requirements.txt

cd .ci/ansible/

TAG=ci_build

if [ -e $REPO_ROOT/../pulp_file ]; then
  PULP_FILE=./pulp_file
else
  PULP_FILE=git+https://github.com/pulp/pulp_file.git@1.6
fi

if [ -e $REPO_ROOT/../pulp_container ]; then
  PULP_CONTAINER=./pulp_container
else
  PULP_CONTAINER=git+https://github.com/pulp/pulp_container.git@2.5
fi

if [ -e $REPO_ROOT/../pulp_rpm ]; then
  PULP_RPM=./pulp_rpm
else
  PULP_RPM=git+https://github.com/pulp/pulp_rpm.git@3.11
fi

if [ -e $REPO_ROOT/../pulp_deb ]; then
  PULP_DEB=./pulp_deb
else
  PULP_DEB=git+https://github.com/pulp/pulp_deb.git@2.11
fi
if [[ "$TEST" == "plugin-from-pypi" ]]; then
  PLUGIN_NAME=pulp-2to3-migration
else
  PLUGIN_NAME=./pulp-2to3-migration
fi
if [ "${TAG_BUILD}" = "1" ]; then
  # Install the plugin only and use published PyPI packages for the rest
  # Quoting ${TAG} ensures Ansible casts the tag as a string.
  cat >> vars/main.yaml << VARSYAML
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: pulpcore
    source: pulpcore~=3.11.0
  - name: pulp-2to3-migration
    source:  "${PLUGIN_NAME}"
  - name: pulp_file
    source: pulp_file
  - name: pulp_container
    source: pulp_container
  - name: pulp_rpm
    source: pulp_rpm
  - name: pulp_deb
    source: pulp_deb
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
else
  cat >> vars/main.yaml << VARSYAML
image:
  name: pulp
  tag: "${TAG}"
plugins:
  - name: pulp-2to3-migration
    source: "${PLUGIN_NAME}"
  - name: pulp_file
    source: $PULP_FILE
  - name: pulp_container
    source: $PULP_CONTAINER
  - name: pulp_rpm
    source: $PULP_RPM
  - name: pulp_deb
    source: $PULP_DEB
  - name: pulpcore
    source: ./pulpcore
services:
  - name: pulp
    image: "pulp:${TAG}"
    volumes:
      - ./settings:/etc/pulp
VARSYAML
fi

cat >> vars/main.yaml << VARSYAML
pulp_settings: null
VARSYAML

ansible-playbook build_container.yaml
ansible-playbook start_container.yaml

echo ::group::PIP_LIST
cmd_prefix bash -c "pip3 list && pip3 install pipdeptree && pipdeptree"
echo ::endgroup::
