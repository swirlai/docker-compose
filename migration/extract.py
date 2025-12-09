# extract_objects.py
import json
import os

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "swirl_server.settings")
django.setup()

from swirl.models import AIProvider, Authenticator, SearchProvider

# Define per-model sensitive fields
SENSITIVE_FIELDS = {
    "Authenticator": {
        "client_secret",
        "password",
        "secret_key",
        "date_created",
        "date_updated",
    },
    "SearchProvider": {"api_key", "password", "token", "date_created",
                       "date_updated"},
    "AIProvider": {"api_key", "password", "token", "date_created",
                   "date_updated"},
}

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


def export_queryset(qs):
    return [serialize_instance(obj) for obj in qs]


def main():
    ai_providers = export_queryset(SearchProvider.objects.all())
    authenticators = export_queryset(Authenticator.objects.all())
    ai_providers = export_queryset(AIProvider.objects.all())

    payload = {
        "authenticators": authenticators,
        "search_providers": ai_providers,
        "ai_providers": ai_providers,
    }

    with open("/app/migration/extract.json", "w") as f:
        json.dump(payload, f, indent=2)


if __name__ == "__main__":
    main()
