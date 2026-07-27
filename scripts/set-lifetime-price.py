#!/usr/bin/env python3
"""Set Sober's lifetime IAP USA base price to $39.99."""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE_ID = "com.jackwallner.sober"
PRODUCT_ID = "com.jackwallner.sober.pro.lifetime"
CUSTOMER_PRICE = "39.99"


def main() -> None:
    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    iaps = asc_lib.list_all(client, f"/apps/{app['id']}/inAppPurchasesV2?limit=200")
    iap = next((row for row in iaps if row["attributes"]["productId"] == PRODUCT_ID), None)
    if iap is None:
        raise SystemExit(f"error: missing {PRODUCT_ID}")

    asc_lib.API = "https://api.appstoreconnect.apple.com/v2"
    try:
        points = asc_lib.list_all(
            client,
            f"/inAppPurchases/{iap['id']}/pricePoints?filter[territory]=USA&limit=200",
        )
    finally:
        asc_lib.API = "https://api.appstoreconnect.apple.com/v1"
    point = next(
        (row for row in points if row["attributes"]["customerPrice"] == CUSTOMER_PRICE),
        None,
    )
    if point is None:
        raise SystemExit(f"error: no USA ${CUSTOMER_PRICE} lifetime price point")

    client.post(
        "/inAppPurchasePriceSchedules",
        {
            "data": {
                "type": "inAppPurchasePriceSchedules",
                "relationships": {
                    "inAppPurchase": {"data": {"type": "inAppPurchases", "id": iap["id"]}},
                    "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                    "manualPrices": {"data": [{"type": "inAppPurchasePrices", "id": "${price0}"}]},
                },
            },
            "included": [
                {
                    "type": "inAppPurchasePrices",
                    "id": "${price0}",
                    "attributes": {"startDate": None},
                    "relationships": {
                        "inAppPurchasePricePoint": {
                            "data": {"type": "inAppPurchasePricePoints", "id": point["id"]}
                        }
                    },
                }
            ],
        },
    )
    print(f"lifetime: USA ${CUSTOMER_PRICE}")


if __name__ == "__main__":
    main()
