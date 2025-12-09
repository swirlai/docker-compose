import json

with open("/migration/extract.json") as f:
    src = json.load(f)

def translate_authenticator(a):
    return {
        "name": a["name"],
        "type": a["type"],
        # DO NOT copy secret
        "secret": None,  # force re-entry later, or omit entirely
        # handle any new schema fields here
    }

def translate_search_provider(sp):
    return {
        "name": sp["name"],
        "type": sp["type"],
        # map fields, set defaults, etc.
        # "new_field": sp.get("old_field", "default_value")
    }

def translate_ai_provider(sp):
    return {
        "name": sp["name"],
        "type": sp["type"],
        # map fields, set defaults, etc.
        # "new_field": sp.get("old_field", "default_value")
    }


dst = {
    "authenticators": [translate_authenticator(a) for a in src["authenticators"]],
    "search_providers": [translate_search_provider(sp) for sp in src["search_providers"]],
    "ai_providers": [translate_ai_provider(ap) for ap in src["ai_providers"]],
}

with open("/migration/load.json", "w") as f:
    json.dump(dst, f, indent=2)
