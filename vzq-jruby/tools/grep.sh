#!/usr/bin/env sh

find . | grep -e scala$ -e rb$ -e java$ | xargs grep --color "$@"
