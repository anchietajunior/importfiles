# Design

This is a small Rails 8.1 API on SQLite.
It ingests the NPPES weekly files and answers three questions: search providers by name, filter them by state and taxonomy, and look one up by NPI.
[README.md](README.md) explains how to run it.

Before deciding anything, I downloaded three consecutive weekly files (97,459 rows) and measured them.
Most of what follows comes from what I found there, which is why the numbers are quoted.

## What the data taught me

Three things in the files shaped the design more than anything else.

A deactivated NPI arrives with nothing but the NPI and the deactivation date.
That is about 2% of the rows, and it is why most columns are nullable.

A deactivation date does not mean the provider is deactivated.
356 rows carry one and are active, because the provider was reactivated later.

The same NPI shows up again in the following week: 895 of them between weeks 1 and 2.
So overlapping files are the normal case, and an older file can carry stale data.

## Data model

I kept four tables.
`providers` has one row per NPI.
`provider_taxonomies` has one row per provider and code, which turns the taxonomy filter into an indexed lookup.
`imports` and `import_rejections` record what each run did.

A few choices are worth explaining.

I store a single `name`, either "FIRST LAST" or the organization name, instead of three columns.
Someone typing "JOHN SMITH" is searching across two source columns, and one column makes that a single comparison.
The price is that the API cannot return first and last name separately.

I store the two dates as they come and derive "active" from them: never deactivated, or reactivated on or after the deactivation.
The rule agrees with the source in all 97,459 rows.

Uniqueness lives in the database.
The unique index on `npi` is what actually makes a re-run safe; the code only relies on it.

## Indexes

There are four, and each one exists for a question the app asks.
I checked the query plans against the 95,086 real providers.

| Index | What it is for |
|---|---|
| `providers(npi)`, unique | Lookup by NPI, the lookup the import does for every row, and the ordering of every page |
| `providers(state)` | The state filter |
| `provider_taxonomies(code)` | The taxonomy filter: it finds the providers for a code, then reads each one by primary key |
| `provider_taxonomies(provider_id, code)`, unique | No repeated code per provider, and reading the codes of a provider straight from the index |

What I left without an index, and why:

- `provider_id` alone, because the unique index already starts with it.
- `name`, because a "contains" search cannot use a B-tree. When name comes with state or taxonomy, the indexed filter narrows first and the name is compared only against that subset.
- The two dates, because 98% of providers are active and an index would narrow nothing.
- `(state, npi)`, which would spare a sort. California, the largest state with 12,556 providers, is filtered and sorted in 5 ms, so I did not add it yet.

## Keep, skip, reject

| Row | What I do with it |
|---|---|
| Provider with entity type 1 or 2 | Keep |
| Deactivation row (NPI and date only) | Keep, and clear the provider's details, as the source does |
| Foreign address with a free-text state | Keep as sent |
| Row older than what is already stored | Skip, and count it |
| The 306 columns I do not read | Skip |
| Invalid CSV, wrong column count, NPI not 10 digits, date not `MM/DD/YYYY`, unknown entity type, no name, no Last Update Date | Reject, with line number and reason |

Rejected rows are stored in `import_rejections` and printed by the rake task.
Every run adds up: rows read equals imported plus skipped plus rejected, so no row goes unaccounted for.

## Running it again

I looked at four ways a re-run could go wrong.

The same file twice, or two overlapping files.
Rows are matched by NPI, and taxonomy codes are replaced by difference, so running a file again changes nothing.

An older file after a newer one.
A row is applied only if its date is not older than what is stored for that provider.
A deactivation row has no Last Update Date, so I use its deactivation date.

A failure halfway through.
The whole file runs in one transaction: it is applied completely or not at all, and the import is marked as failed with the reason.

A broken line.
The file is read one physical line at a time, so a bad line is rejected on its own and the rest goes in.
This assumes no line breaks inside fields, which holds for every row I measured.

To prove it, I imported weeks 1, 2 and 3, then week 1 again, and then weeks 3, 2 and 1 on an empty database.
All three end with identical data: 95,086 providers.

## If CMS changes the columns

I read columns by header name, never by position, and the names are listed once in `NppesFile::Row`.

Reordered or new columns change nothing.
A renamed or removed column makes the import fail before it writes anything, and the error names the missing column.
I preferred that to importing blanks, which would silently wipe a field for every provider in the file.
The fix is one string.

One case is not handled: a 16th taxonomy column would be ignored without any warning.

## API

`GET /providers/:npi` returns any NPI, and a deactivated one comes back with `"active": false`.
Knowing that an NPI exists but is deactivated seemed more useful than a 404.

`GET /providers?name=&state=&taxonomy=&page=` returns active providers only, 50 per page.
The name search is a case-insensitive "contains".
Fuzzy search was a bonus and I left it out.

## Performance

I measured week 1, which has 29,158 rows.

The import takes 18 seconds.
The rake task turns SQL logging off, because with it the same import took 46 seconds in development.

It runs 4.3 SQL statements per row, one at a time through ActiveRecord, and 2.0 when nothing changed.
I kept it that way on purpose: it is the easiest code to read and to change live, and a weekly file in about 20 seconds is not a problem to solve.

Memory peaks near 115 MB whether the file has 29,158 or 97,459 rows, and whatever the number of rejected rows.

I know where this stops working.
The monthly file, with 9 million rows, would take hours; the way out is `upsert_all` in batches.
The name search scans the table, 23 ms on 95,086 providers; the way out is SQLite FTS5.

## What I would do next

I would ingest the official taxonomy list, the NUCC code set, which is a free CSV.
It would go into a `taxonomies` table with one row per code, and `provider_taxonomies` would point to it.
One taxonomy would then be related to many providers.
Today the code is repeated as text: 119,801 rows for 762 distinct codes.

I measured the gain on the real data: the taxonomy table and its indexes go from 8.0 MB to 4.5 MB.
The API could also return the description of each code, not only the code.
It costs a second file to ingest, a join in the taxonomy filter, and a rule for codes that are not in the list.

## What I left out

- Fuzzy search.
- Separate name fields, addresses and which taxonomy is the primary one.
- The other files in the zip, and the monthly files.
- Checking the NPI check digit.
- Downloading the file, scheduling and background jobs.
- Authentication and totals in the paginated answers.
- An HTTP endpoint for imports and rejections, since the table and the rake output already make them observable.
- The Rails pieces the app does not use: Solid Queue, Solid Cache, Active Storage and the Docker files.
