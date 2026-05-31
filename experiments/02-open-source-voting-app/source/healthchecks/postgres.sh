#!/bin/sh
set -e
pg_isready -U "$POSTGRES_USER"
