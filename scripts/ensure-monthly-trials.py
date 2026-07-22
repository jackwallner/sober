#!/usr/bin/env python3
"""Idempotently add Sober's one-week monthly trial in every priced territory."""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE_ID = "com.jackwallner.sober"
MONTHLY_PRODUCT_ID = "com.jackwallner.sober.pro.monthly"


def territory_from_id(encoded_id: str) -> str | None:
    padded = encoded_id + "=" * ((4 - len(encoded_id) % 4) % 4)
    try:
        payload = json.loads(base64.urlsafe_b64decode(padded))
    except (ValueError, json.JSONDecodeError):
        return None
    return payload.get("i") or payload.get("c")


def main() -> None:
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    groups = asc_lib.list_all(client, f"/apps/{app['id']}/subscriptionGroups?limit=200")
    subscriptions = []
    for group in groups:
        subscriptions.extend(
            asc_lib.list_all(client, f"/subscriptionGroups/{group['id']}/subscriptions?limit=200")
        )
    monthly = next(
        (item for item in subscriptions if item["attributes"]["productId"] == MONTHLY_PRODUCT_ID),
        None,
    )
    if monthly is None:
        raise SystemExit(f"error: subscription not found: {MONTHLY_PRODUCT_ID}")

    subscription_id = monthly["id"]
    prices = asc_lib.list_all(
        client,
        f"/subscriptions/{subscription_id}/prices?include=territory&limit=200",
    )
    priced = {
        territory
        for price in prices
        if (
            territory := (
                price.get("relationships", {}).get("territory", {}).get("data") or {}
            ).get("id")
        )
    }
    existing = asc_lib.list_all(
        client,
        f"/subscriptions/{subscription_id}/introductoryOffers?include=territory&limit=200",
    )
    covered = {
        territory
        for offer in existing
        if offer["attributes"].get("offerMode") == "FREE_TRIAL"
        and offer["attributes"].get("duration") == "ONE_WEEK"
        and offer["attributes"].get("numberOfPeriods") == 1
        and (
            territory := (
                offer.get("relationships", {}).get("territory", {}).get("data") or {}
            ).get("id")
        )
    }
    missing = sorted(priced - covered)
    print(f"priced={len(priced)} covered={len(covered)} missing={len(missing)}")

    for territory in missing:
        client.post(
            "/subscriptionIntroductoryOffers",
            {
                "data": {
                    "type": "subscriptionIntroductoryOffers",
                    "attributes": {
                        "duration": "ONE_WEEK",
                        "offerMode": "FREE_TRIAL",
                        "numberOfPeriods": 1,
                    },
                    "relationships": {
                        "subscription": {
                            "data": {"type": "subscriptions", "id": subscription_id}
                        },
                        "territory": {"data": {"type": "territories", "id": territory}},
                    },
                }
            },
        )
        print(f"added {territory}")


if __name__ == "__main__":
    main()
