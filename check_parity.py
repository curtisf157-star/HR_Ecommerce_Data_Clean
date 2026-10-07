# check_parity.py
import duckdb
import pandas as pd
import numpy as np

con = duckdb.connect("clean.duckdb")

hr_sql = con.sql("SELECT * FROM hr_clean").df()
ec_sql = con.sql("SELECT * FROM ecommerce_clean").df()

hr_py = pd.read_csv("hr_clean.csv",        keep_default_na=False, na_values=[""])
ec_py = pd.read_csv("ecommerce_clean.csv", keep_default_na=False, na_values=[""])


def norm(v):
    if v is None:
        return "__NULL__"
    try:
        if pd.isna(v):
            return "__NULL__"
    except (TypeError, ValueError):
        pass

    if isinstance(v, (pd.Timestamp, np.datetime64)):
        return pd.Timestamp(v).strftime("%Y-%m-%d")
    try:
        ts = pd.Timestamp(v)
        if not pd.isna(ts) and len(str(v)) >= 8:
            return ts.strftime("%Y-%m-%d")
    except (ValueError, TypeError):
        pass

    s = str(v).strip()
    return "__NULL__" if s == "" else s


def compare(name, a, b, key):
    print(f"\n=== {name} ===")
    print(f"rows        sql={len(a):>7}   csv={len(b):>7}")
    print(f"columns same:    {list(a.columns) == list(b.columns)}")

    b = b[a.columns]
    a = a.sort_values(key).reset_index(drop=True)
    b = b.sort_values(key).reset_index(drop=True)

    diff_count = 0
    for col in a.columns:
        if pd.api.types.is_numeric_dtype(a[col]) and pd.api.types.is_numeric_dtype(b[col]):
            fa = a[col].astype("float64").round(6)
            fb = b[col].astype("float64").round(6)
            eq = ((fa == fb) | (fa.isna() & fb.isna())).to_numpy()
        else:
            sa = np.array([norm(v) for v in a[col].to_numpy()], dtype=object)
            sb = np.array([norm(v) for v in b[col].to_numpy()], dtype=object)
            eq = sa == sb

        bad = np.where(~eq)[0]
        if len(bad):
            diff_count += len(bad)
            print(f"\n  DIFF  {col}: {len(bad)} rows differ")
            for i in bad[:5]:
                print(f"    row {i} ({key}={a.iloc[i][key]}):")
                print(f"       sql = {a[col].iloc[i]!r}")
                print(f"       csv = {b[col].iloc[i]!r}")

    if diff_count == 0:
        print("\n  ✅ identical (all columns, all rows)")
    else:
        print(f"\n  ❌ {diff_count} total cell mismatches")


compare("HR",        hr_sql, hr_py, "Employee_ID")
compare("Ecommerce", ec_sql, ec_py, "Order_ID")

con.close()