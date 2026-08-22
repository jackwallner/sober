#!/usr/bin/env python3
"""Move Sober's free-trial introductory offers to a new duration, everywhere.

App Store Connect has no "edit duration" on an introductory offer: the existing
offer has to be deleted and a new one created per territory, per product. At 175
priced territories across monthly and yearly that is ~700 calls, so this is
idempotent and resumable — territories already on the target duration are
skipped, and a partial run can simply be re-run.

Defaults to a dry run. Pass --apply to write.

    python3 scripts/set-trial-length.py                 # show the plan
    python3 scripts/set-trial-length.py --apply         # 7 -> 14 days
    python3 scripts/set-trial-length.py --duration ONE_WEEK --apply   # roll back

Existing subscribers are untouched: an introductory offer only applies to an
Apple ID that has never had one on this subscription group, so changing it
cannot alter anyone's current billing. Anyone mid-trial keeps the terms they
started under.
"""
from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE_ID = "com.jackwallner.sober"
PRODUCT_IDS = [
    "com.jackwallner.sober.pro.monthly",
    "com.jackwallner.sober.pro.yearly",
]
# ASC's subscription-offer duration enum. Anything outside this set is rejected
# by the API, so validate locally rather than discovering it on call 300.
DURATIONS = [
    "THREE_DAYS", "ONE_WEEK", "TWO_WEEKS", "ONE_MONTH",
    "TWO_MONTHS", "THREE_MONTHS", "SIX_MONTHS", "ONE_YEAR",
]


def territory_of(row: dict) -> str | None:
    return (row.get("relationships", {}).get("territory", {}).get("data") or {}).get("id")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--duration", default="TWO_WEEKS", choices=DURATIONS)
    parser.add_argument("--apply", action="store_true", help="actually write; default is a dry run")
    args = parser.parse_args()

    client = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app = asc_lib.find_app(client, BUNDLE_ID)
    groups = asc_lib.list_all(client, f"/apps/{app['id']}/subscriptionGroups?limit=200")
    subscriptions = []
    for group in groups:
        subscriptions.extend(
            asc_lib.list_all(client, f"/subscriptionGroups/{group['id']}/subscriptions?limit=200")
        )
    by_product = {row["attributes"]["productId"]: row for row in subscriptions}

    total = Counter()
    for product_id in PRODUCT_IDS:
        subscription = by_product.get(product_id)
        if subscription is None:
            raise SystemExit(f"error: subscription not found: {product_id}")
        sid = subscription["id"]

        priced = {
            territory
            for row in asc_lib.list_all(client, f"/subscriptions/{sid}/prices?include=territory&limit=200")
            if (territory := territory_of(row))
        }
        offers = asc_lib.list_all(
            client, f"/subscriptions/{sid}/introductoryOffers?include=territory&limit=200"
        )
        free_trials = [o for o in offers if o["attributes"].get("offerMode") == "FREE_TRIAL"]

        on_target = {
            territory
            for o in free_trials
            if o["attributes"].get("duration") == args.duration
            and o["attributes"].get("numberOfPeriods") == 1
            and (territory := territory_of(o))
        }
        stale = [o for o in free_trials if territory_of(o) not in on_target]
        missing = sorted(priced - on_target)

        current = Counter(o["attributes"].get("duration") for o in free_trials)
        print(
            f"\n{product_id}\n  priced={len(priced)} "
            f"already {args.duration}={len(on_target)} "
            f"to delete={len(stale)} to create={len(missing)}\n"
            f"  current durations: {dict(current)}"
        )
        total["delete"] += len(stale)
        total["create"] += len(missing)

        if not args.apply:
            continue

        for offer in stale:
            # asc_lib.ASCClient exposes get/post/patch only; DELETE goes through
            # the generic request method.
            client.request("DELETE", f"/subscriptionIntroductoryOffers/{offer['id']}")
        for territory in missing:
            client.post(
                "/subscriptionIntroductoryOffers",
                {
                    "data": {
                        "type": "subscriptionIntroductoryOffers",
                        "attributes": {
                            "duration": args.duration,
                            "offerMode": "FREE_TRIAL",
                            "numberOfPeriods": 1,
                        },
                        "relationships": {
                            "subscription": {"data": {"type": "subscriptions", "id": sid}},
                            "territory": {"data": {"type": "territories", "id": territory}},
                        },
                    }
                },
            )
        print(f"  applied: deleted {len(stale)}, created {len(missing)}")

    if not args.apply:
        print(
            f"\nDry run. Would delete {total['delete']} offers and create {total['create']}. "
            "Re-run with --apply."
        )


if __name__ == "__main__":
    main()
