#!/bin/bash
set -eu

if [[ -d example-private-repository ]] ; then
  rm -rf example-private-repository
fi

echo "+++ Cloning private repository with https"
git clone -- https://github.com/lox/example-private-repository.git example-private-repository
rm -rf example-private-repository