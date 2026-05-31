#!/bin/sh
set -e
redis-cli ping | grep -q PONG
