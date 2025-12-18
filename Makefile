# Makefile for building migration tarball
# Usage:
#   make FROM=v4_0_0_0 TO=v4_4_0_0
#
# This will produce:
#   migration_v4_0_0_0_to_v4_4_0_0.tar.gz
#
# The archive will contain the migration/ directory and its contents.

FROM ?=
TO   ?=

# Fail fast if FROM or TO is not set
ifeq ($(FROM),)
  $(error FROM is not set. Usage: make FROM=v4_0_0_0 TO=v4_4_0_0)
endif

ifeq ($(TO),)
  $(error TO is not set. Usage: make FROM=v4_0_0_0 TO=v4_4_0_0)
endif

TAR_NAME := migration_$(FROM)_to_$(TO).tar.gz

.PHONY: all clean

all: $(TAR_NAME)

$(TAR_NAME): migration/*
	tar czf $@ migration

clean:
	rm -f migration_*.tar.gz
