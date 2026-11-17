#!/usr/bin/env python3
"""Import DB-IP Lite country CSV ranges into PageClock's local Postgres lookup.

Download the DB-IP Lite Country CSV from https://db-ip.com/db/download/ip-to-country-lite
and run:
  pip install -r scripts/geoip-requirements.txt
  DATABASE_URL='postgresql://...' python scripts/import_dbip_country.py /path/to/dbip-country-lite.csv

DATABASE_URL must be a direct/session-pooler connection with permission to replace
public.ip_country_ranges. The script stores only CIDR + ISO country metadata.
"""
import argparse
import csv
import ipaddress
import os
import sys
from datetime import date

import psycopg2
from psycopg2.extras import execute_values
import pycountry

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_file")
    parser.add_argument("--source-version", default=date.today().isoformat())
    args = parser.parse_args()
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        sys.exit("DATABASE_URL is required; do not commit it or paste it into chat.")

    rows = []
    with open(args.csv_file, newline="", encoding="utf-8") as source:
        reader = csv.reader(source)
        for line_no, row in enumerate(reader, 1):
            if len(row) < 3:
                continue
            start_ip, end_ip, country_code = row[0].strip(), row[1].strip(), row[2].strip().upper()
            if country_code in ("", "-", "ZZ"):
                continue
            try:
                first, last = ipaddress.ip_address(start_ip), ipaddress.ip_address(end_ip)
                if first.version != last.version or first > last:
                    continue
                country = pycountry.countries.get(alpha_2=country_code)
                if not country:
                    continue
                for network in ipaddress.summarize_address_range(first, last):
                    rows.append((str(network), country_code, country.name, args.source_version))
            except ValueError:
                # Skip a header row or malformed source line.
                if line_no == 1:
                    continue
                raise

            if len(rows) >= 5000:
                flush(rows, database_url)
                rows.clear()

    if rows:
        flush(rows, database_url)
    print("Import complete. Validate IPv4 and IPv6 sample lookups before enabling the Auth Hook.")

def flush(rows, database_url):
    with psycopg2.connect(database_url) as connection:
        with connection.cursor() as cursor:
            if getattr(flush, "first_batch", True):
                cursor.execute("TRUNCATE public.ip_country_ranges")
                flush.first_batch = False
            execute_values(cursor, """
                INSERT INTO public.ip_country_ranges
                  (network, country_code, country_name, source_version, updated_at)
                VALUES %s
                ON CONFLICT (network) DO UPDATE SET
                  country_code = EXCLUDED.country_code,
                  country_name = EXCLUDED.country_name,
                  source_version = EXCLUDED.source_version,
                  updated_at = now()
            """, [(*row, ) for row in rows], template="(%s::cidr, %s, %s, %s, now())")
        connection.commit()

if __name__ == "__main__":
    main()
