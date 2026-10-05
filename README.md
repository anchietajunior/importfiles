# NPPES provider API

Ingests NPPES NPI weekly files and serves a query API over them.
The design decisions are in [DESIGN.md](DESIGN.md).

## Setup

Requires Ruby 4.0.3.

```sh
bundle install
bin/rails db:prepare
```

## Import a file

Download a weekly file from https://download.cms.gov/nppes/NPI_Files.html and unzip it.
The file to import is the one named `npidata_pfile_<dates>.csv`.

```sh
bin/rails 'nppes:import[path/to/npidata_pfile_20260907-20260913.csv]'
```

The task prints how many rows were imported, skipped and rejected, and the first rejected lines.
Every run is stored in the `imports` table, and every rejected line in `import_rejections`.
Running it again on the same file, or on another week in any order, is safe.

## Columns read from the file

The file has 330 columns; the import reads these 24, by header name.
The mapping lives in `NppesFile::Row`.

| CSV column | Stored in | Conversion |
|---|---|---|
| `NPI` | `providers.npi` | As sent |
| `Entity Type Code` | `providers.entity_type` | Kept as the number; the model and the API read `1` as `individual` and `2` as `organization` |
| `Provider Organization Name (Legal Business Name)` | `providers.name` | As sent, when present |
| `Provider First Name` and `Provider Last Name (Legal Name)` | `providers.name` | Joined as "FIRST LAST", when there is no organization name |
| `Provider Business Practice Location Address State Name` | `providers.state` | As sent |
| `Last Update Date` | `providers.last_updated_on` | `MM/DD/YYYY` to a date |
| `NPI Deactivation Date` | `providers.deactivated_on` | `MM/DD/YYYY` to a date; also fills `last_updated_on` when `Last Update Date` is blank |
| `NPI Reactivation Date` | `providers.reactivated_on` | `MM/DD/YYYY` to a date |
| `Healthcare Provider Taxonomy Code_1` to `_15` | `provider_taxonomies.code` | One row per distinct code |

A blank field is stored as `NULL`.

## Query

```sh
bin/rails server

curl 'localhost:3000/providers/1255289328'
curl 'localhost:3000/providers?name=smith'
curl 'localhost:3000/providers?state=TX&taxonomy=207Q00000X'
curl 'localhost:3000/providers?name=smith&state=TX&page=2'
```

## Tests

```sh
bin/rails test
```
