# Makefile for building migration tarball
# Usage:
#   make FROM=v4_0_0_0 TO=v4_4_0_0
#   make deployment
#
# This will produce:
#   migration_v4_0_0_0_to_v4_4_0_0.tar.gz
#   deployment_YYYY-MM-DD_HHMM.tar.gz
#
# The migration archive contains only migration/
# The deployment archive contains the entire working directory

FROM ?=
TO   ?=

# Fail fast if FROM or TO is not set (only when needed)
ifeq ($(filter deployment clean,$(MAKECMDGOALS)),)
  ifeq ($(FROM),)
    $(error FROM is not set. Usage: make FROM=v4_0_0_0 TO=v4_4_0_0)
  endif
  ifeq ($(TO),)
    $(error TO is not set. Usage: make FROM=v4_0_0_0 TO=v4_4_0_0)
  endif
endif

TAR_NAME := migration_$(FROM)_to_$(TO).tar.gz
DEPLOY_TS := $(shell date +"%Y-%m-%d_%H%M")
DEPLOY_TAR := deployment_$(DEPLOY_TS).tar.gz

.PHONY: all clean deployment

all: $(TAR_NAME)

$(TAR_NAME): migration/*
	tar czf $@ migration

deployment:
	tar czf $(DEPLOY_TAR) \
		--exclude=.git \
		--exclude='*.tar.gz' \
		.

clean:
	rm -f migration_*.tar.gz deployment_*.tar.gz
