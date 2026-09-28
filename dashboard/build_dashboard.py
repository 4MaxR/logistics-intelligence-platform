"""
LOGISTICS INTELLIGENCE PLATFORM — DASHBOARD BUILD
=================================================
Reads the 14 source CSVs in ../data, aggregates them with the same
formulas as the gold-layer views (sql/04_business_views.sql), checks the
headline KPIs against the verified values in docs/KPI.md, and writes a
self-contained HTML dashboard.

    python dashboard/build_dashboard.py

Output: dashboard/logistics_dashboard.html (template: dashboard/template.html)
"""

import json
import math
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
DATA = HERE.parent / "data"
TEMPLATE = HERE / "template.html"
OUTPUT = HERE / "logistics_dashboard.html"
YEARS = [2022, 2023, 2024]


# ----------------------------------------------------------------------
# Load
# ----------------------------------------------------------------------
def read(name, dates=()):
    df = pd.read_csv(DATA / f"{name}.csv")
    for col in dates:
        df[col] = pd.to_datetime(df[col], format="ISO8601")
    return df


loads = read("loads", ["load_date"])
trips = read("trips", ["dispatch_date"])
events = read("delivery_events", ["scheduled_datetime", "actual_datetime"])
fuel = read("fuel_purchases", ["purchase_date"])
maint = read("maintenance_records", ["maintenance_date"])
safety = read("safety_incidents", ["incident_date"])
truck_m = read("truck_utilization_metrics", ["month"])
customers = read("customers")
routes = read("routes")
facilities = read("facilities")
drivers = read("drivers")
trucks = read("trucks")

# gold.fact_load: gross_revenue AS revenue + fuel_surcharge + accessorial_charges
loads["gross"] = loads.revenue + loads.fuel_surcharge + loads.accessorial_charges
loads["year"] = loads.load_date.dt.year
loads["month"] = loads.load_date.dt.strftime("%Y-%m")

# gold.fact_delivery: date_sk = CAST(scheduled_datetime AS DATE)
events["year"] = events.scheduled_datetime.dt.year
events["month"] = events.scheduled_datetime.dt.strftime("%Y-%m")
events["on_time"] = events.on_time_flag.astype(int)
events["late_min"] = (events.actual_datetime - events.scheduled_datetime).dt.total_seconds() / 60

trips["year"] = trips.dispatch_date.dt.year
trips["month"] = trips.dispatch_date.dt.strftime("%Y-%m")

load_dims = loads[["load_id", "customer_id", "route_id", "load_type", "booking_type", "year", "gross"]]
ev = events.merge(load_dims.drop(columns="year").rename(columns={"gross": "load_gross"}), on="load_id", how="left")
ev = ev.merge(trips[["trip_id", "driver_id", "truck_id"]], on="trip_id", how="left")
dlv = ev[ev.event_type == "Delivery"]
tr = trips.merge(load_dims.drop(columns="year"), on="load_id", how="left")

assert ev.load_type.notna().all(), "delivery events reference loads that do not exist"
assert tr.load_type.notna().all(), "trips reference loads that do not exist"


# ----------------------------------------------------------------------
# Verify headline KPIs against docs/KPI.md (verified on SQL Server 2025)
# ----------------------------------------------------------------------
def check(label, actual, expected, tol):
    ok = abs(actual - expected) <= tol
    print(f"  {'OK ' if ok else 'FAIL'} {label:<28} {actual:,.4f}  (docs: {expected:,})")
    if not ok:
        raise SystemExit(f"KPI mismatch: {label}")


print("Verifying headline KPIs against docs/KPI.md")
check("gross revenue", loads.gross.sum(), 298_621_429, 1)
check("gross revenue 2022 ($M)", loads[loads.year == 2022].gross.sum() / 1e6, 99.9, 0.05)
check("gross revenue 2023 ($M)", loads[loads.year == 2023].gross.sum() / 1e6, 98.9, 0.05)
check("gross revenue 2024 ($M)", loads[loads.year == 2024].gross.sum() / 1e6, 99.8, 0.05)
check("trips", len(trips), 85_410, 0)
check("delivery events", len(dlv), 85_410, 0)
check("on-time deliveries", dlv.on_time.sum(), 38_102, 0)
check("on-time %", round(100 * dlv.on_time.mean(), 1), 44.6, 0)
for y, v in zip(YEARS, [44.7, 44.6, 44.6]):
    check(f"on-time % {y}", round(100 * dlv[dlv.year == y].on_time.mean(), 1), v, 0)
check("total miles", trips.actual_distance_miles.sum(), 122_159_201, 0)
check("avg mpg", round(trips.average_mpg.mean(), 2), 6.50, 0)
check("avg utilization %", round(100 * truck_m.utilization_rate.mean(), 1), 83.0, 0)
check("fuel spend ($M)", round(fuel.total_cost.sum() / 1e6, 1), 95.6, 0)
check("safety claims ($M)", round(safety.claim_amount.sum() / 1e6, 2), 2.65, 0)
check("safety incidents", len(safety), 170, 0)
check("preventable incidents", safety.preventable_flag.sum(), 64, 0)


# ----------------------------------------------------------------------
# Aggregate — compact {cols, rows} tables, pre-grouped at the grain the
# filters need (year or month × load_type × booking_type)
# ----------------------------------------------------------------------
def table(df):
    out = df.copy()
    for c in out.columns:
        if pd.api.types.is_float_dtype(out[c]):
            out[c] = out[c].round(3)
        elif pd.api.types.is_integer_dtype(out[c]) or pd.api.types.is_bool_dtype(out[c]):
            out[c] = out[c].astype(int)
    return {"cols": list(out.columns), "rows": out.values.tolist()}


LT_BT = ["load_type", "booking_type"]

loads_m = loads.groupby(["month", *LT_BT]).agg(
    loads=("load_id", "count"), gross=("gross", "sum"), revenue=("revenue", "sum"),
    surcharge=("fuel_surcharge", "sum"), accessorial=("accessorial_charges", "sum"),
).reset_index()

deliv_m = ev.groupby(["month", *LT_BT, "event_type"]).agg(
    events=("event_id", "count"), on_time=("on_time", "sum"), det=("detention_minutes", "sum"),
).reset_index()

# Tables attribute each delivery to its load's booking year so a row's
# loads, revenue and service describe the same set of loads.
dlv_by_load = dlv.merge(loads[["load_id", "year"]], on="load_id", suffixes=("_evt", ""))

cust = loads.groupby(["year", "customer_id", *LT_BT]).agg(loads=("load_id", "count"), gross=("gross", "sum"))
cust = cust.join(dlv_by_load.groupby(["year", "customer_id", *LT_BT]).agg(
    deliveries=("event_id", "count"), on_time=("on_time", "sum"), det=("detention_minutes", "sum"),
)).fillna(0).reset_index()

lanes = loads.groupby(["year", "route_id", *LT_BT]).agg(loads=("load_id", "count"), gross=("gross", "sum"))
lanes = lanes.join(dlv_by_load.groupby(["year", "route_id", *LT_BT]).agg(
    deliveries=("event_id", "count"), on_time=("on_time", "sum"),
)).fillna(0).reset_index()

fac = dlv.groupby(["year", "facility_id", *LT_BT]).agg(
    events=("event_id", "count"), on_time=("on_time", "sum"), det=("detention_minutes", "sum"),
).reset_index()

trips_m = tr.assign(unassigned=tr.truck_id.isna(), un_rev=np.where(tr.truck_id.isna(), tr.gross, 0.0)).groupby(
    ["month", *LT_BT]).agg(
    trips=("trip_id", "count"), miles=("actual_distance_miles", "sum"), mpg=("average_mpg", "sum"),
    idle=("idle_time_hours", "sum"), unassigned=("unassigned", "sum"), un_rev=("un_rev", "sum"),
).reset_index()

drv_trips = tr[tr.driver_id.notna()]
drv = drv_trips.groupby(["year", "driver_id", *LT_BT]).agg(
    trips=("trip_id", "count"), miles=("actual_distance_miles", "sum"), mpg=("average_mpg", "sum"),
    idle=("idle_time_hours", "sum"),
)
drv_dlv = dlv.merge(trips[["trip_id", "year"]], on="trip_id", suffixes=("_evt", ""))
drv = drv.join(drv_dlv[drv_dlv.driver_id.notna()].groupby(["year", "driver_id", *LT_BT]).agg(
    deliveries=("event_id", "count"), on_time=("on_time", "sum"),
)).fillna(0).reset_index()

truck_m["year"] = truck_m.month.dt.year
trucks_y = truck_m.groupby(["year", "truck_id"]).agg(
    months=("month", "count"), util=("utilization_rate", "sum"), mpg=("average_mpg", "sum"),
    trips=("trips_completed", "sum"), miles=("total_miles", "sum"), revenue=("total_revenue", "sum"),
    maint_events=("maintenance_events", "sum"), maint_cost=("maintenance_cost", "sum"),
    downtime=("downtime_hours", "sum"),
).reset_index()

fuel["month"] = fuel.purchase_date.dt.strftime("%Y-%m")
fuel_m = fuel.groupby("month").agg(
    purchases=("fuel_purchase_id", "count"), gallons=("gallons", "sum"), cost=("total_cost", "sum"),
).reset_index()

maint["year"] = maint.maintenance_date.dt.year
maint_y = maint.groupby(["year", "maintenance_type"]).agg(
    events=("maintenance_id", "count"), cost=("total_cost", "sum"), downtime=("downtime_hours", "sum"),
).reset_index()

safety["year"] = safety.incident_date.dt.year
safety_rows = safety[["year", "incident_type", "at_fault_flag", "injury_flag", "preventable_flag", "claim_amount"]]


# ----------------------------------------------------------------------
# Dimensions
# ----------------------------------------------------------------------
def dim(df, key, cols):
    return {r[key]: [None if isinstance(r[c], float) and math.isnan(r[c]) else r[c] for c in cols]
            for r in df.to_dict("records")}


routes["corridor"] = routes.origin_city + " → " + routes.destination_city
drivers["name"] = drivers.first_name + " " + drivers.last_name
dims = {
    "customers": {"cols": ["name", "type", "status"],
                  "map": dim(customers, "customer_id", ["customer_name", "customer_type", "account_status"])},
    "routes": {"cols": ["corridor", "miles", "origin", "destination"],
               "map": dim(routes.assign(o=routes.origin_city + ", " + routes.origin_state,
                                        d=routes.destination_city + ", " + routes.destination_state),
                          "route_id", ["corridor", "typical_distance_miles", "o", "d"])},
    "facilities": {"cols": ["name", "city", "state", "type"],
                   "map": dim(facilities, "facility_id", ["facility_name", "city", "state", "facility_type"])},
    "drivers": {"cols": ["name", "terminal", "experience", "status"],
                "map": dim(drivers, "driver_id", ["name", "home_terminal", "years_experience", "employment_status"])},
    "trucks": {"cols": ["unit", "make", "model_year", "terminal", "status"],
               "map": dim(trucks, "truck_id", ["unit_number", "make", "model_year", "home_terminal", "status"])},
}


# ----------------------------------------------------------------------
# Key findings — computed over the full period so the prose can't drift
# ----------------------------------------------------------------------
def pct(x, d=1):
    return round(100 * x, d)


on_time_year = {y: pct(dlv[dlv.year == y].on_time.mean()) for y in YEARS}
monthly_ot = dlv[dlv.year.isin(YEARS)].groupby("month").on_time.mean()
p = dlv.on_time.mean()
drv_rate = dlv[dlv.driver_id.notna()].groupby("driver_id").on_time.agg(["mean", "count"])
fac_rate = dlv.groupby("facility_id").agg(ot=("on_time", "mean"), det=("detention_minutes", "mean"))
seg = {k: pct(v) for k, v in dlv.groupby("load_type").on_time.mean().items()}
seg.update({k: pct(v) for k, v in dlv.groupby("booking_type").on_time.mean().items()})
late = dlv[dlv.on_time == 0]

price = {y: fuel[fuel.purchase_date.dt.year == y] for y in YEARS}
ppg = {y: price[y].total_cost.sum() / price[y].gallons.sum() for y in YEARS}
mpg_year = {y: round(trips[trips.year == y].average_mpg.mean(), 2) for y in YEARS}
savings_2024 = price[2024].gallons.sum() * (ppg[2022] - ppg[2024])

acct = loads.groupby("customer_id").gross.sum().sort_values(ascending=False)
top_id = acct.index[0]
xyz = customers[customers.customer_name == "XYZ Wholesale"].customer_id
unassigned = tr[tr.truck_id.isna()]
tu = truck_m.groupby("truck_id").agg(u=("utilization_rate", "mean"), m=("average_mpg", "mean"))

findings = {
    "on_time_year": on_time_year,
    "on_time_month_min": pct(monthly_ot.min()), "on_time_month_max": pct(monthly_ot.max()),
    "pickup_on_time": pct(ev[ev.event_type == "Pickup"].on_time.mean()),
    "late_median_min": round(late.late_min.median()),
    "driver_sd": round(100 * drv_rate["mean"].std(), 2),
    "driver_sd_chance": round(100 * math.sqrt(p * (1 - p) / drv_rate["count"].median()), 2),
    "driver_min": pct(drv_rate["mean"].min()), "driver_max": pct(drv_rate["mean"].max()),
    "drivers": int(len(drv_rate)),
    "fac_ot_min": pct(fac_rate.ot.min()), "fac_ot_max": pct(fac_rate.ot.max()),
    "fac_det_min": round(fac_rate.det.min(), 1), "fac_det_max": round(fac_rate.det.max(), 1),
    "segments": seg,
    "det_delivery": round(ev[ev.event_type == "Delivery"].detention_minutes.mean(), 1),
    "det_pickup": round(ev[ev.event_type == "Pickup"].detention_minutes.mean(), 1),
    "det_on_time": round(dlv[dlv.on_time == 1].detention_minutes.mean(), 1),
    "det_late": round(dlv[dlv.on_time == 0].detention_minutes.mean(), 1),
    "ppg": {y: round(v, 3) for y, v in ppg.items()},
    "ppg_change": pct(ppg[2024] / ppg[2022] - 1),
    "mpg_year": mpg_year,
    "savings_2024": round(savings_2024),
    "accounts": int(customers.customer_id.nunique()),
    "names": int(customers.customer_name.nunique()),
    "top_account": {"id": top_id, "name": customers.set_index("customer_id").customer_name[top_id],
                    "gross": round(acct.iloc[0]), "share": pct(acct.iloc[0] / acct.sum(), 2)},
    "xyz_accounts": int(len(xyz)), "xyz_gross": round(loads[loads.customer_id.isin(xyz)].gross.sum()),
    "unassigned_share": pct(len(unassigned) / len(trips)), "unassigned_trips": int(len(unassigned)),
    "unassigned_revenue": round(unassigned.gross.sum()),
    "trucks_with_metrics": int(truck_m.truck_id.nunique()), "trucks_total": int(len(trucks)),
    "util_min": pct(tu.u.min()), "util_max": pct(tu.u.max()), "util_mpg_r": round(tu.u.corr(tu.m), 2),
    "fuel_2025_rows": int((fuel.purchase_date.dt.year == 2025).sum()),
    "fuel_2025_cost": round(fuel[fuel.purchase_date.dt.year == 2025].total_cost.sum()),
    "events_2025": int((ev.year == 2025).sum()),
}

payload = {
    "built": datetime.now().strftime("%Y-%m-%d %H:%M"),
    "source_rows": int(sum(len(pd.read_csv(f, usecols=[0])) for f in DATA.glob("*.csv"))),
    "years": YEARS,
    "load_types": sorted(loads.load_type.unique().tolist()),
    "booking_types": sorted(loads.booking_type.unique().tolist()),
    "loads_m": table(loads_m), "deliv_m": table(deliv_m), "trips_m": table(trips_m),
    "cust": table(cust), "lanes": table(lanes), "fac": table(fac), "drv": table(drv),
    "trucks_y": table(trucks_y), "fuel_m": table(fuel_m), "maint_y": table(maint_y),
    "safety": table(safety_rows), "dims": dims, "findings": findings,
}

blob = json.dumps(payload, separators=(",", ":"), ensure_ascii=False, default=lambda o: o.item())
blob = blob.replace("</", "<\\/")
html = TEMPLATE.read_text(encoding="utf-8").replace("/*__DATA__*/null", blob)
OUTPUT.write_text(html, encoding="utf-8")
print(f"Source rows: {payload['source_rows']:,}")
print(f"Wrote {OUTPUT.relative_to(HERE.parent)} ({OUTPUT.stat().st_size / 1024:,.0f} KB, data {len(blob) / 1024:,.0f} KB)")
