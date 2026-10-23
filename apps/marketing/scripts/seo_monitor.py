import argparse
import datetime
import json
import subprocess


GSC = "google-search-console/webmasters/v3/sites/sc-domain%3Afrontman.sh/searchAnalytics/query"
GA = "google-analytics/v1beta/properties/524112512:runReport"


def call(endpoint, body):
    process = subprocess.run(
        ["treg", "--json", "call", endpoint, "--data", json.dumps(body)],
        capture_output=True, text=True, check=True, timeout=120,
    )
    response = json.loads(process.stdout)
    if response.get("_treg", {}).get("http_status") != 200 or "result" not in response:
        raise RuntimeError(f"API request failed: {endpoint}")
    result = response["result"]
    if "error" in result:
        raise RuntimeError(f"API returned an error: {endpoint}")
    if len(result.get("rows", [])) >= 25000:
        raise RuntimeError("Dimension row limit reached. Narrow the reporting window.")
    return result


def periods(end, days):
    if days < 7 or days > 28 or days % 7:
        raise ValueError("Use 7, 14, 21, or 28 days for matched weekdays.")
    start = end - datetime.timedelta(days=days - 1)
    return {
        "previous": ((start - datetime.timedelta(days=days)).isoformat(),
                     (start - datetime.timedelta(days=1)).isoformat()),
        "recent": (start.isoformat(), end.isoformat()),
    }


def search(start, end, dimensions=None, filters=None):
    body = {"startDate": start, "endDate": end, "type": "web",
            "dataState": "final", "rowLimit": 25000}
    if dimensions:
        body["dimensions"] = dimensions
    if filters:
        body["dimensionFilterGroups"] = [{"filters": filters}]
    return call(GSC, body).get("rows", [])


def collect(end, days):
    windows = periods(end, days)
    first = windows["previous"][0]
    daily = search(first, end.isoformat(), ["date"])
    dates = {row["keys"][0] for row in daily}
    expected = {(end - datetime.timedelta(days=i)).isoformat() for i in range(days * 2)}
    if dates != expected:
        raise ValueError("Incomplete final daily data. Use an earlier END_DATE.")
    snapshot = {"collected_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                "property": "sc-domain:frontman.sh", "ga4_property": "524112512",
                "days_per_period": days, "periods": {}, "daily": daily}
    for name, (start, finish) in windows.items():
        totals = search(start, finish)
        if len(totals) != 1:
            raise ValueError(f"Expected one aggregate total for {name}.")
        snapshot["periods"][name] = {
            "start": start, "end": finish, "totals": totals[0],
            "pages": search(start, finish, ["page"]),
            "homepage_queries": search(start, finish, ["query", "country", "device"], [
                {"dimension": "page", "operator": "equals", "expression": "https://frontman.sh/"},
                {"dimension": "query", "operator": "includingRegex", "expression": "^frontman( ai)?$"},
            ]),
        }
    ga_body = {
        "dateRanges": [{"startDate": start, "endDate": finish, "name": name}
                       for name, (start, finish) in windows.items()],
        "dimensionFilter": {"andGroup": {"expressions": [
            {"filter": {"fieldName": field, "stringFilter": {"matchType": "EXACT", "value": value}}}
            for field, value in [("sessionSourceMedium", "google / organic"), ("hostName", "frontman.sh")]
        ]}},
        "metrics": [{"name": name} for name in ["sessions", "engagedSessions", "keyEvents"]],
        "limit": 25000,
    }
    snapshot["ga4_organic"] = call(GA, ga_body)
    snapshot["ga4_landing_pages"] = call(GA, {
        **ga_body, "dimensions": [{"name": "landingPage"}],
    })
    snapshot["ga4_events"] = call(GA, {
        **ga_body, "dimensions": [{"name": "eventName"}],
        "metrics": [{"name": "eventCount"}, {"name": "keyEvents"}],
    })
    previous = snapshot["periods"]["previous"]["totals"]
    recent = snapshot["periods"]["recent"]["totals"]
    snapshot["change_percent"] = {
        metric: (recent[metric] / previous[metric] - 1) * 100 if previous[metric] else None
        for metric in ["clicks", "impressions"]
    }
    snapshot["limits"] = [
        "Query rows omit anonymized traffic. Never sum them as site totals.",
        "Page aggregation differs from property aggregation. Average position changes with query mix.",
        "Clicks, sessions, outbound intent, and confirmed customer outcomes are different measures.",
        "GA4 is consent-dependent. Key events depend on the property's event configuration.",
        "This command reads APIs only. It does not deploy, schedule monitoring, or inspect manual actions.",
    ]
    return snapshot


def main():
    parser = argparse.ArgumentParser(description="Compare complete Frontman Google organic reporting periods.")
    parser.add_argument("--end-date", required=True, type=datetime.date.fromisoformat)
    parser.add_argument("--days", type=int, default=14)
    args = parser.parse_args()
    try:
        print(json.dumps(collect(args.end_date, args.days), indent=2))
    except (ValueError, RuntimeError, subprocess.SubprocessError) as error:
        parser.exit(1, f"{error}\n")


if __name__ == "__main__":
    main()
