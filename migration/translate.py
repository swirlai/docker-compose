#!/usr/bin/env python
import argparse
import json
import os
import sys

import django
from django.core.exceptions import ValidationError

# -------------------------------------------------------------------
# Django setup
# -------------------------------------------------------------------
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "swirl_server.settings")
django.setup()

from swirl.models import AIProvider, Authenticator, SearchProvider

# -------------------------------------------------------------------
# Config
# -------------------------------------------------------------------

# Fields that must NEVER be migrated (PKs, etc.)
ALWAYS_SKIP_FIELDS = {"id", "pk"}

# Sensitive fields that we don't want to copy from extract.json
SENSITIVE_FIELDS = {
    "Authenticator": {"client_secret", "password", "secret_key", "api_key", "token"},
    "SearchProvider": {"api_key", "password", "token", "secret_key"},
    "AIProvider": {"api_key", "secret_key", "password", "token"},
}

# Fields that will be assigned during load, not translate,
# so we skip validating them here.
VALIDATION_EXCLUDE_FIELDS = {
    "SearchProvider": {"owner"},
    "Authenticator": {"owner"},
    "AIProvider": {"owner"},
}

# Explicit per-model field defaults for cases where:
# - we do NOT want to migrate the old value (e.g. secrets)
# - there is no model-level default
# - null=True but we prefer a placeholder string
EXPLICIT_FIELD_DEFAULTS = {
    "Authenticator": {
        "client_secret": "<client-secret>",
        # add more as needed
    },
    "AIProvider": {
        "defaults": [""],
    },
}


def log(msg: str) -> None:
    print(f"[translate.py] {msg}", file=sys.stderr)


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

def concrete_fields_for_model(model_cls):
    """Return concrete, local, non-relational fields for a model."""
    fields = []
    for f in model_cls._meta.get_fields():
        if not getattr(f, "concrete", False):
            continue
        if getattr(f, "many_to_many", False):
            continue
        if f.is_relation:
            continue
        if f.name in ALWAYS_SKIP_FIELDS:
            continue
        fields.append(f)
    return fields


def build_field_value(model_name: str, field, src_dict: dict):
    """
    Decide what value to assign to a field:
      - if present in src_dict and not sensitive:
          - if non-blank → use that value
          - if blank and explicit default exists → use explicit default
      - if sensitive:
          - if explicit default is configured: use placeholder default
          - else: skip field entirely (do not set in result)
      - else if explicit default exists: use that
      - else if field has default: use default
      - else if field.null: use None
      - else if auto_now/auto_now_add: skip (let model fill it)
      - else: raise, because we cannot guess a valid value
    """
    name = field.name
    sensitive = SENSITIVE_FIELDS.get(model_name, set())
    explicit_defaults = EXPLICIT_FIELD_DEFAULTS.get(model_name, {})

    # Sensitive fields: never copy the old value
    if name in sensitive:
        if name in explicit_defaults:
            value = explicit_defaults[name]
            log(
                f"{model_name}.{name}: sensitive field, using explicit placeholder "
                f"default: {value!r}"
            )
            return value, False  # set this value in result
        else:
            log(f"{model_name}.{name}: sensitive field, skipping (no explicit default)")
            return None, True  # skipped=True → caller omits from result

    # Non-sensitive: use source value if present
    if name in src_dict:
        raw_value = src_dict[name]

        # Consider "blank" source values as missing if we have an explicit default
        is_blank = (
            raw_value is None
            or raw_value == ""
            or raw_value == []
            or raw_value == {}
            or (isinstance(raw_value, str) and raw_value.strip() == "")
        )

        if is_blank and name in explicit_defaults:
            value = explicit_defaults[name]
            log(
                f"{model_name}.{name}: source value is blank; "
                f"using explicit default {value!r}"
            )
            return value, False

        # Otherwise, use the value as-is
        return raw_value, False

    # Non-sensitive: explicit default in our mapping
    if name in explicit_defaults:
        value = explicit_defaults[name]
        log(f"{model_name}.{name}: using explicit default: {value!r}")
        return value, False

    # Auto timestamp / auto-managed fields: let the model handle them at save time
    if getattr(field, "auto_now", False) or getattr(field, "auto_now_add", False):
        log(f"{model_name}.{name}: auto_now/auto_now_add field, skipping")
        return None, True  # skipped → not included in result

    # Not in src: fall back to model defaults / null rules
    if field.has_default():
        try:
            value = field.get_default()
        except TypeError:
            value = field.default() if callable(field.default) else field.default
        return value, False

    if getattr(field, "null", False):
        return None, False

    # Required, non-null, no default, and missing in source data
    raise RuntimeError(
        f"{model_name}.{name} is required, has no default, "
        f"and is missing from extract.json and EXPLICIT_FIELD_DEFAULTS, "
        "and is not an auto-managed field. "
        "You may need to handle this field explicitly in translate.py."
    )


def translate_record(model_cls, src_dict: dict) -> dict:
    """
    Build a dict suitable for instantiating model_cls(**data) based on:
      - the current (4.4) schema
      - the extracted data
      - default values and nullability

    Also:
      - skips sensitive fields
      - does NOT include pk/id
    """
    model_name = model_cls.__name__
    result = {}

    for field in concrete_fields_for_model(model_cls):
        try:
            value, skipped = build_field_value(model_name, field, src_dict)
        except RuntimeError as e:
            # Bubble this up so we fail early and loudly
            log(f"ERROR while translating {model_name} field '{field.name}': {e}")
            raise

        if skipped:
            # Sensitive or auto-managed field: don't put it in the result at all
            continue

        result[field.name] = value

    return result


def translate_and_validate(model_cls, records, kind_label: str):
    """
    Translate a list of source dicts into a list of validated dicts for model_cls.
    For each record:
      - build a translated dict
      - instantiate model_cls(**data)
      - run full_clean() with:
          * validate_unique=False
          * validate_constraints=False
          * exclude = fields we intentionally set at load time
    """
    model_name = model_cls.__name__
    output = []

    for idx, src in enumerate(records, start=1):
        name = src.get("name") or f"<unnamed-{idx}>"
        log(f"Translating {kind_label} {idx}: {name}")

        data = translate_record(model_cls, src)

        instance = model_cls(**data)

        # Figure out which fields to skip during validation
        exclude_fields = list(VALIDATION_EXCLUDE_FIELDS.get(model_name, set()))

        try:
            try:
                # Newer Django supports validate_constraints
                instance.full_clean(
                    validate_unique=False,
                    validate_constraints=False,
                    exclude=exclude_fields,
                )
            except TypeError:
                # Older Django: no validate_constraints
                instance.full_clean(
                    validate_unique=False,
                    exclude=exclude_fields,
                )
        except ValidationError as ve:
            log(
                f"ValidationError for {model_name} '{name}': "
                f"{getattr(ve, 'message_dict', ve)}"
            )
            raise

        output.append(data)

    return output


# -------------------------------------------------------------------
# CLI / Main
# -------------------------------------------------------------------

def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Translate extract.json from an older Swirl deployment into "
            "load.json compatible with the current model schema."
        )
    )
    parser.add_argument(
        "-i",
        "--input",
        dest="input_path",
        default="/app/migration/extract.json",
        help="Path to input extract JSON (default: /app/migration/extract.json)",
    )
    parser.add_argument(
        "-o",
        "--output",
        dest="output_path",
        default="/app/migration/load.json",
        help="Path to output load JSON (default: /app/migration/load.json)",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    src_path = args.input_path
    dst_path = args.output_path

    if not os.path.exists(src_path):
        raise SystemExit(f"Source file not found: {src_path}")

    with open(src_path, "r") as f:
        src = json.load(f)

    src_auths = src.get("authenticators", [])
    src_sps = src.get("search_providers", [])
    src_ais = src.get("ai_providers", [])

    log(
        f"Loaded {len(src_auths)} authenticators, "
        f"{len(src_sps)} search providers, "
        f"{len(src_ais)} AI providers from {src_path}"
    )

    dst_auths = translate_and_validate(Authenticator, src_auths, "authenticator")
    dst_sps = translate_and_validate(SearchProvider, src_sps, "search provider")
    dst_ais = translate_and_validate(AIProvider, src_ais, "AI provider")

    dst = {
        "authenticators": dst_auths,
        "search_providers": dst_sps,
        "ai_providers": dst_ais,
    }

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    with open(dst_path, "w") as f:
        json.dump(dst, f, indent=2)

    log(f"Wrote translated, validated data to {dst_path}")


if __name__ == "__main__":
    main()
