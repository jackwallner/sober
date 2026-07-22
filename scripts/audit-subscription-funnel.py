#!/usr/bin/env python3
"""Audit Sober subscription pricing and one-week trial territory coverage."""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE_ID = "com.jackwallner.sober"
EXPECTED_PRODUCTS = {
    "monthly": "com.jackwallner.sober.pro.monthly",
    "yearly": "com.jackwallner.sober.pro.yearly",
}


def territory_from_id(encoded_id: str) -> str | None:
    padded = encoded_id + "=" * ((4 - len(encoded_id) % 4) % 4)
    try:
        payload = json.loads(base64.urlsafe_b64decode(padded))
    except (ValueError, json.JSONDecodeError):
        return None
    return payload.get("i") or payload.get("c")


def territory_ids(rows: list[dict]) -> set[str]:
    result = set()
    for row in rows:
        relationship = row.get("relationships", {}).get("territory", {}).get("data") or {}
        territory = relationship.get("id") or territory_from_id(row["id"])
        if territory:
            result.add(territory)
    return result


def main() -> None:
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    groups = asc_lib.list_all(client, f"/apps/{app['id']}/subscriptionGroups?limit=200")
    subscriptions = []
    for group in groups:
        subscriptions.extend(
            asc_lib.list_all(client, f"/subscriptionGroups/{group['id']}/subscriptions?limit=200")
        )
    by_product = {item["attributes"]["productId"]: item for item in subscriptions}

    failed = False
    for label, product_id in EXPECTED_PRODUCTS.items():
        subscription = by_product.get(product_id)
        if subscription is None:
            print(f"{label}: MISSING {product_id}")
            failed = True
            continue

        subscription_id = subscription["id"]
        prices = asc_lib.list_all(client, f"/subscriptions/{subscription_id}/prices?include=territory&limit=200")
        offers = asc_lib.list_all(
            client,
            f"/subscriptions/{subscription_id}/introductoryOffers?include=territory&limit=200",
        )
        priced = territory_ids(prices)
        trial = territory_ids(
            [
                offer
                for offer in offers
                if offer["attributes"].get("offerMode") == "FREE_TRIAL"
                and offer["attributes"].get("duration") == "ONE_WEEK"
                and offer["attributes"].get("numberOfPeriods") == 1
            ]
        )
        missing = sorted(priced - trial)
        state = subscription["attributes"].get("state", "UNKNOWN")
        print(
            f"{label}: state={state} priced={len(priced)} "
            f"one_week_trials={len(trial)} missing={','.join(missing) or 'none'}"
        )
        if state != "APPROVED" or missing:
            failed = True

    raise SystemExit(1 if failed else 0)


if __name__ == "__main__":
    main()
