#!/usr/bin/env python
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


# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------

def main():
    load_path = "./migration/load.json"

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
        f"{len(src_ais)} AI providers."
    )

    admin_user = get_admin_user()

    # We will replace all existing objects with the translated ones
    with transaction.atomic():
        # ------------------------------------------------------------------
        # 1. Wipe existing data
        # ------------------------------------------------------------------
        auth_count = Authenticator.objects.count()
        sp_count = SearchProvider.objects.count()
        ai_count = AIProvider.objects.count()

        log(f"Deleting {auth_count} existing Authenticators...")
        Authenticator.objects.all().delete()

        log(f"Deleting {sp_count} existing SearchProviders...")
        SearchProvider.objects.all().delete()

        log(f"Deleting {ai_count} existing AIProviders...")
        AIProvider.objects.all().delete()

        # ------------------------------------------------------------------
        # 2. Recreate from load.json
        # ------------------------------------------------------------------

        # Authenticators
        created_auths = 0
        for a_data in src_auths:
            # a_data already validated by translate.py
            obj = Authenticator.objects.create(**a_data)
            created_auths += 1
        log(f"Created {created_auths} Authenticators.")

        # SearchProviders
        created_sps = 0
        sp_has_owner = model_has_field(SearchProvider, "owner")

        for sp_data in src_sps:
            data_copy = dict(sp_data)

            if sp_has_owner:
                # Always assign owner to admin at load time
                data_copy["owner"] = admin_user

            obj = SearchProvider.objects.create(**data_copy)
            created_sps += 1

        log(f"Created {created_sps} SearchProviders (owner set to admin where applicable).")

        # AIProviders
        created_ais = 0
        ai_has_owner = model_has_field(AIProvider, "owner")

        for ap_data in src_ais:
            data_copy = dict(ap_data)

            if ai_has_owner:
                # Only if AIProvider has an owner field (future-proof)
                data_copy["owner"] = admin_user

            obj = AIProvider.objects.create(**data_copy)
            created_ais += 1

        log(f"Created {created_ais} AIProviders.")

    log("Load process completed successfully.")


if __name__ == "__main__":
    main()
