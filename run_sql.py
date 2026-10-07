# run_sql.py
from pathlib import Path
import duckdb

BASE_DIR = Path(__file__).resolve().parent
DB_PATH  = BASE_DIR / "clean.duckdb"

con = duckdb.connect(str(DB_PATH))


def strip_leading_comments(stmt: str) -> str:
    """Remove leading -- comment lines and blank lines, return the first real line onward."""
    lines = stmt.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line == "" or line.startswith("--"):
            i += 1
        else:
            break
    return "\n".join(lines[i:])


for name in ["02_clean_hr.sql", "03_clean_ecommerce.sql", "04_analysis.sql"]:
    sql_path = BASE_DIR / name

    if not sql_path.exists():
        print(f"\n>>> Skipping {name} (not found)")
        continue

    print(f"\n>>> Running {sql_path.name}")
    sql_text = sql_path.read_text()

    statements = [s.strip() for s in sql_text.split(";") if s.strip()]

    for stmt in statements:
        body = strip_leading_comments(stmt)
        if not body:
            continue

        head = body.lstrip().upper()

        if head.startswith("SELECT") or head.startswith("WITH"):
            result = con.sql(stmt).df()
            first_line = body.splitlines()[0][:70]
            print(f"\n--- {first_line}...")
            print(result)
        else:
            con.execute(stmt)

con.close()
print("\nDone.")