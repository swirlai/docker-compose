import json
import os

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "swirl_server.settings")
django.setup()

from swirl.models import AIProvider, Authenticator, SearchProvider

with open("/migration/load.json") as f:
    data = json.load(f)

for a_data in data["authenticators"]:
    obj, created = Authenticator.objects.get_or_create(
        name=a_data["name"],
        defaults={
            # non-secret fields...
        },
    )

for sp_data in data["search_providers"]:
    obj, created = SearchProvider.objects.update_or_create(
        name=sp_data["name"],
        defaults={
            # map fields...
        },
    )

for sp_data in data["ai_providers"]:
    obj, created = AIProvider.objects.update_or_create(
        name=sp_data["name"],
        defaults={
            # map fields...
        },
    )
