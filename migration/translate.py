#!/usr/bin/env python
import json
import os
import sys

import django
from django.core.exceptions import ValidationError

# -------------------------------------------------------------------
# Django setup
# -------------------------------------------------------------------
# FIXME: update this to your actual settings module
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "your_project.settings")
django.setup()

# FIXME: update imports to your real model locations
from yourapp.models import Authenticator, SearchProvider, AIProvider  # type: ignore


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
      - if present in src_dict and not sensitive: use that value
      - else if field has default: use default
      - else if field.null: use None
      - else: raise, because we cannot guess a valid value
    """
    name = field.name
    sensitive = SENSITIVE_FIELDS.get(model_name, set())

    # Skip sensitive fields entirely (we never migrate secrets)
    if name in sensitive:
        log(f"{model_name}.{name}: skipping sensitive field")
        return None, True  # value=None, skipped=True (won't be set in result)

    if name in src_dict:
        # Use the value as extracted (it already came from the old DB)
        return src_dict[name], False

    # Not in src: fall back to defaults / null rules
    if field.has_default():
        try:
            value = field.get_default()
        except TypeError:
            # Very old Django versions may not have get_default(); fall back
            value = field.default() if callable(field.default) else field.default
        return value, False

    if getattr(field, "null", False):
        return None, False

    # Required, non-null, no default, and missing in source data
    raise RuntimeError(
        f"{model_name}.{name} is required, has no default, "
        f"and is missing from extract.json. "
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
            # Sensitive field: don't put it in the result at all
            continue

        result[field.name] = value

    return result


def translate_and_validate(model_cls, records, kind_label: str):
    """
    Translate a list of source dicts into a list of validated dicts for model_cls.
    For each record:
      - build a translated dict
      - instantiate model_cls(**data)
      - run full_clean()
    """
    model_name = model_cls.__name__
    output = []

    for idx, src in enumerate(records, start=1):
        name = src.get("name") or f"<unnamed-{idx}>"
        log(f"Translating {kind_label} {idx}: {name}")

        data = translate_record(model_cls, src)

        # Instantiate unsaved instance for validation
        instance = model_cls(**data)
        try:
            instance.full_clean()
        except ValidationError as ve:
            log(
                f"ValidationError for {model_name} '{name}': {ve.message_dict if hasattr(ve, 'message_dict') else ve}"
            )
            raise

        output.append(data)

    return output


# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------

def main():
    src_path = "./migration/extract.json"
    dst_path = "./migration/load.json"

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
        f"{len(src_ais)} AI providers from extract.json"
    )

    dst_auths = translate_and_validate(Authenticator, src_auths, "authenticator")
    dst_sps = translate_and_validate(SearchProvider, src_sps, "search provider")
    dst_ais = translate_and_validate(AIProvider, src_ais, "AI provider")

    dst = {
        "authenticators": dst_auths,
        "search_providers": dst_sps,
        "ai_providers": dst_ais,
    }

    with open(dst_path, "w") as f:
        json.dump(dst, f, indent=2)

    log(f"Wrote translated, validated data to {dst_path}")


if __name__ == "__main__":
    main()
