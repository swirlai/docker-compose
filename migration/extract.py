#!/usr/bin/env python
################################################################################
# extract_objects.py
# Example usage:
# python ./migration/extract_objects.py -a
# python ./migration/extract_objects.py authenticators -n 'Azure'
# python ./migration/extract_objects.py search_providers ai_providers -n '^OpenAI'
# python ./migration/extract_objects.py -a -n 'SharePoint'


import argparse
import json
import os
import re
import sys

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "swirl_server.settings")
django.setup()

from swirl.models import AIProvider, Authenticator, SearchProvider  # type: ignore

# Define per-model sensitive fields
SENSITIVE_FIELDS = {
    "Authenticator": {
        "client_secret",
        "password",
        "secret_key",
        "date_created",
        "date_updated",
    },
    "SearchProvider": {
        "api_key",
        "password",
        "token",
        "date_created",
        "date_updated",
    },
    "AIProvider": {
        "api_key",
        "password",
        "token",
        "date_created",
        "date_updated",
    },
}

# Map CLI object type names -> (Model, payload_key)
OBJECT_TYPES = {
    "authenticators": (Authenticator, "authenticators"),
    "search_providers": (SearchProvider, "search_providers"),
    "ai_providers": (AIProvider, "ai_providers"),
}


def log(msg: str) -> None:
    print(f"[extract_objects.py] {msg}", file=sys.stderr)


def serialize_instance(obj):
    model_name = obj.__class__.__name__
    sensitive = SENSITIVE_FIELDS.get(model_name, set())

    data = {}
    for field in obj._meta.get_fields():
        # Only dump concrete, local, non-relational fields
        if not getattr(field, "concrete", False):
            continue
        if getattr(field, "many_to_many", False):
            continue
        if field.is_relation:
            continue

        name = field.name
        if name in sensitive:
            continue

        data[name] = getattr(obj, name)

    return data


def export_queryset(qs, name_regex=None):
    """
    Export objects from queryset, optionally filtering by name regex.
    name_regex: compiled regex or None
    """
    results = []
    for obj in qs:
        if name_regex is not None:
            name = getattr(obj, "name", "")
            if not isinstance(name, str):
                name = str(name)
            if not name_regex.search(name):
                continue
        results.append(serialize_instance(obj))
    return results


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Extract selected Swirl objects into /app/migration/extract.json.\n\n"
            "You must either specify -a/--all or one or more object types:\n"
            "  authenticators, search_providers, ai_providers"
        )
    )
    parser.add_argument(
        "-a",
        "--all",
        action="store_true",
        help="Dump all supported object types "
             "(authenticators, search_providers, ai_providers)",
    )
    parser.add_argument(
        "objects",
        nargs="*",
        help="Specific object types to dump "
             "(authenticators, search_providers, ai_providers)",
    )
    parser.add_argument(
        "-n",
        "--name",
        dest="name_pattern",
        help="Optional regex to filter objects by their name field. "
             "Only matching records will be exported.",
    )
    args = parser.parse_args()

    if not args.all and not args.objects:
        parser.error(
            "You must specify either -a/--all or at least one object type "
            "(authenticators, search_providers, ai_providers)."
        )

    return args


def main():
    args = parse_args()

    # Compile name regex if provided
    name_regex = None
    if args.name_pattern:
        try:
            name_regex = re.compile(args.name_pattern)
        except re.error as e:
            raise SystemExit(
                f"Invalid regex for --name / -n: {args.name_pattern!r} ({e})"
            )
        log(f"Name filter regex compiled: {args.name_pattern!r}")

    # Determine which object types to dump
    if args.all:
        selected_keys = list(OBJECT_TYPES.keys())
    else:
        # Normalize and validate provided object names
        selected_keys = []
        for name in args.objects:
            key = name.strip().lower()
            if key not in OBJECT_TYPES:
                raise SystemExit(
                    f"Unknown object type '{name}'. "
                    f"Valid options: {', '.join(OBJECT_TYPES.keys())}"
                )
            if key not in selected_keys:
                selected_keys.append(key)

    log(f"Selected object types to extract: {', '.join(selected_keys)}")

    payload = {}

    for key in selected_keys:
        model_cls, payload_key = OBJECT_TYPES[key]
        log(f"Exporting {payload_key} from model {model_cls.__name__}...")
        qs = model_cls.objects.all()
        exported = export_queryset(qs, name_regex=name_regex)
        payload[payload_key] = exported
        log(f"  -> {len(exported)} objects exported.")

    # -----------------------------
    # Dynamic output filename logic
    # -----------------------------
    # Base on selected object types
    type_part = "_".join(selected_keys)

    # Slugified representation of name regex (if present)
    name_part = ""
    if args.name_pattern:
        # Replace non-alnum with '-', collapse repeats, strip edges
        slug = re.sub(r"[^A-Za-z0-9]+", "-", args.name_pattern).strip("-")
        if slug:
            name_part = f"__name_{slug}"

    base_filename = f"extract_{type_part}{name_part}.json"

    migration_dir = "/app/migration"
    os.makedirs(migration_dir, exist_ok=True)

    descriptive_path = os.path.join(migration_dir, base_filename)
    canonical_path = os.path.join(migration_dir, "extract.json")

    # Write descriptive file
    with open(descriptive_path, "w") as f:
        json.dump(payload, f, indent=2)

    # Also update canonical extract.json so translate/load don't need to change
    # (just copy the same content)
    with open(canonical_path, "w") as f:
        json.dump(payload, f, indent=2)

    log(f"Wrote extract data to {descriptive_path}")
    log(f"Canonical extract updated at {canonical_path}")


if __name__ == "__main__":
    main()
