#!/usr/bin/env python
import argparse
import json
import os
import sys

import django
from django.contrib.auth import get_user_model
from django.db import transaction

# -------------------------------------------------------------------
# Django setup
# -------------------------------------------------------------------
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "swirl_server.settings")
django.setup()

# NOTE:
# This script runs as server-side code with direct access to Django’s ORM and
# database. It does not perform an application-level login or create a session.
# `get_admin_user()` simply queries the User table and returns a model instance.
# Assigning `owner = admin_user` sets the corresponding foreign key in the DB.
# The authority for this operation comes from the DB credentials in SQL_*,
# not from Django authentication or permissions.


from swirl.models import AIProvider, Authenticator, SearchProvider  # type: ignore


def log(msg: str) -> None:
    print(f"[load.py] {msg}", file=sys.stderr)


# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

def get_admin_user():
    """
    Return the 'admin' user for ownership assignment.
    Assumes there is a user with username='admin'.
    Falls back to the first superuser if needed.
    """
    User = get_user_model()
    try:
        admin = User.objects.get(username="admin")
        log("Using admin user with username='admin' for ownership.")
        return admin
    except User.DoesNotExist:
        log("User with username='admin' not found; falling back to first superuser.")
        admin = User.objects.filter(is_superuser=True).first()
        if not admin:
            raise RuntimeError(
                "No admin or superuser found. Cannot assign owner. "
                "Please ensure an admin user exists before running load.py."
            )
        log(f"Using superuser '{admin}' for ownership.")
        return admin


def model_has_field(model_cls, field_name: str) -> bool:
    try:
        model_cls._meta.get_field(field_name)
        return True
    except Exception:
        return False


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Load translated Swirl objects from load.json into the target database.\n"
            "\n"
            "By default, runs in create-or-update mode (no deletions).\n"
            "Use -d/--delete together with per-model flags to delete existing rows.\n"
            "If -d is set but no per-model flags are given, all three types are\n"
            "eligible for deletion, but each model is only deleted if the load file\n"
            "contains at least one object of that type."
        )
    )
    parser.add_argument(
        "-i",
        "--input",
        dest="load_path",
        default="./migration/load.json",
        help="Path to load JSON file (default: ./migration/load.json)",
    )
    parser.add_argument(
        "-d",
        "--delete",
        dest="delete_existing",
        action="store_true",
        help=(
            "Enable deletion of existing objects. Combined with per-model flags:\n"
            "  --delete-auth  Delete Authenticators\n"
            "  --delete-sp    Delete SearchProviders\n"
            "  --delete-ai    Delete AIProviders\n"
            "If no per-model flags are provided, all three types are candidates\n"
            "for deletion, but only if that type appears in the load file."
        ),
    )
    parser.add_argument(
        "--delete-auth",
        dest="delete_auth",
        action="store_true",
        help="When used with -d/--delete, delete existing Authenticators "
             "before load (only if at least one authenticator is present "
             "in the load file).",
    )
    parser.add_argument(
        "--delete-sp",
        dest="delete_sp",
        action="store_true",
        help="When used with -d/--delete, delete existing SearchProviders "
             "before load (only if at least one search provider is present "
             "in the load file).",
    )
    parser.add_argument(
        "--delete-ai",
        dest="delete_ai",
        action="store_true",
        help="When used with -d/--delete, delete existing AIProviders "
             "before load (only if at least one AI provider is present "
             "in the load file).",
    )
    return parser.parse_args()


# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------

def main():
    args = parse_args()
    load_path = args.load_path
    delete_existing = args.delete_existing

    if not os.path.exists(load_path):
        raise SystemExit(f"Load file not found: {load_path}")

    with open(load_path, "r") as f:
        data = json.load(f)

    src_auths = data.get("authenticators", [])
    src_sps = data.get("search_providers", [])
    src_ais = data.get("ai_providers", [])

    log(
        f"Preparing to load "
        f"{len(src_auths)} authenticators, "
        f"{len(src_sps)} search providers, "
        f"{len(src_ais)} AI providers "
        f"from {load_path}."
    )

    admin_user = get_admin_user()

    # Decide which models are eligible for deletion
    any_specific_flags = args.delete_auth or args.delete_sp or args.delete_ai

    # Only delete a model if:
    #   - global delete is enabled (-d/--delete), AND
    #   - either its specific flag is set, OR no specific flags were set at all, AND
    #   - there is at least one object of that type in the load file
    delete_auth = (
        delete_existing
        and (args.delete_auth or not any_specific_flags)
        and len(src_auths) > 0
    )
    delete_sp = (
        delete_existing
        and (args.delete_sp or not any_specific_flags)
        and len(src_sps) > 0
    )
    delete_ai = (
        delete_existing
        and (args.delete_ai or not any_specific_flags)
        and len(src_ais) > 0
    )

    with transaction.atomic():
        # --------------------------------------------------------------
        # Optional delete step (per-model)
        # --------------------------------------------------------------
        if delete_existing:
            log("Delete flag is set; applying per-model delete rules.")
            if delete_auth:
                auth_count = Authenticator.objects.count()
                log(
                    f"Deleting {auth_count} existing Authenticators "
                    f"(load file has {len(src_auths)})."
                )
                Authenticator.objects.all().delete()
            else:
                log(
                    "Not deleting Authenticators "
                    f"(either no delete flag for auths, or load file has none)."
                )

            if delete_sp:
                sp_count = SearchProvider.objects.count()
                log(
                    f"Deleting {sp_count} existing SearchProviders "
                    f"(load file has {len(src_sps)})."
                )
                SearchProvider.objects.all().delete()
            else:
                log(
                    "Not deleting SearchProviders "
                    f"(either no delete flag for SPs, or load file has none)."
                )

            if delete_ai:
                ai_count = AIProvider.objects.count()
                log(
                    f"Deleting {ai_count} existing AIProviders "
                    f"(load file has {len(src_ais)})."
                )
                AIProvider.objects.all().delete()
            else:
                log(
                    "Not deleting AIProviders "
                    f"(either no delete flag for AIs, or load file has none)."
                )
        else:
            log("Delete flag not set; existing objects will be updated or created.")

        # --------------------------------------------------------------
        # Upsert from load.json
        # --------------------------------------------------------------

        # Authenticators
        created_auths = 0
        updated_auths = 0

        for a_data in src_auths:
            data_copy = dict(a_data)
            name = data_copy.pop("name", None)
            if not name:
                log("Skipping Authenticator with missing name.")
                continue

            obj, created = Authenticator.objects.update_or_create(
                name=name,
                defaults=data_copy,
            )
            if created:
                created_auths += 1
            else:
                updated_auths += 1

        log(
            f"Processed Authenticators: created={created_auths}, "
            f"updated={updated_auths}."
        )

        # SearchProviders
        created_sps = 0
        updated_sps = 0
        sp_has_owner = model_has_field(SearchProvider, "owner")

        for sp_data in src_sps:
            data_copy = dict(sp_data)
            name = data_copy.pop("name", None)
            if not name:
                log("Skipping SearchProvider with missing name.")
                continue

            if sp_has_owner:
                # Always assign owner to admin at load time
                data_copy["owner"] = admin_user

            obj, created = SearchProvider.objects.update_or_create(
                name=name,
                defaults=data_copy,
            )
            if created:
                created_sps += 1
            else:
                updated_sps += 1

        log(
            f"Processed SearchProviders: created={created_sps}, "
            f"updated={updated_sps} "
            f"(owner set to admin where applicable)."
        )

        # AIProviders
        created_ais = 0
        updated_ais = 0
        ai_has_owner = model_has_field(AIProvider, "owner")

        for ap_data in src_ais:
            data_copy = dict(ap_data)
            name = data_copy.pop("name", None)
            if not name:
                log("Skipping AIProvider with missing name.")
                continue

            if ai_has_owner:
                data_copy["owner"] = admin_user

            obj, created = AIProvider.objects.update_or_create(
                name=name,
                defaults=data_copy,
            )
            if created:
                created_ais += 1
            else:
                updated_ais += 1

        log(
            f"Processed AIProviders: created={created_ais}, "
            f"updated={updated_ais} "
            f"(owner set to admin where applicable)."
        )

    log("Load process completed successfully.")


if __name__ == "__main__":
    main()
