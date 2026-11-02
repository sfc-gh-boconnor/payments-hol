# Lab Companion

A React (Next.js) app on **Snowflake App Runtime** that is installed in every lab account. It gives attendees:

- **Pathways:** choose a persona, and the app orders the modules for it.
- **Instructions:** each module's steps, Cortex Code prompts and SQL with a copy button. This is generated from the repo's vignette READMEs and `.sql` files, so it always matches the tested code.
- **Check my work:** live validation queries against the account, with a pass or fail result and a hint for each check.
- **Progress saved in Snowflake:** results land in `BARCLAYS_HOL.LAB.LAB_PROGRESS`, so they survive refreshes and browser changes.
- **Facilitator view:** `/facilitator` shows every attendee's progress per module, refreshed every 30 seconds.

## How it works

| Piece | Where |
|---|---|
| Content | `lib/content.generated.json`, built by `npm run sync-content` from `../core`, `../vignettes`, `../setup/catchup` |
| Checks | `lib/checks.ts` - one SQL statement per check, returning `OK` and `DETAIL` |
| Pathways | `lib/content.ts` (`PATHWAYS`), matching `../pathways/README.md` |
| Identity and progress | `lib/lab.ts` |
| API | `app/api/checks/[code]` (run checks / latest results), `app/api/progress`, `app/api/facilitator` |

The app is owned by `HOL_ADMIN`. Checks run with the app's own rights, so they can see everything attendees build, and they only read. The attendee's user name is recorded with each result. Attendees reach the app through `USAGE` granted to `HOL_PARTICIPANT`.

## Updating content or checks

```bash
npm run sync-content        # after editing any vignette README or .sql in the repo
npm run build               # local sanity check
```

Commit `lib/content.generated.json`: the deploy uploads only this folder.

When you add a check, test its SQL as `HOL_ADMIN` against a fully built account first. Every check in `lib/checks.ts` was validated that way in the reference account.

## Deploy

`setup/provision_account.sh` does this for each lab account. To deploy by hand:

```bash
snow sql -c <conn> -f ../setup/04_lab_companion.sql
snow app deploy --connection <conn> --role HOL_ADMIN
snow sql -c <conn> --role HOL_ADMIN -q "GRANT USAGE ON APPLICATION SERVICE BARCLAYS_HOL.LAB.LAB_COMPANION TO ROLE HOL_PARTICIPANT"
```

The first deploy takes about 5 minutes: compute provisioning, an in-Snowflake `npm` build, then the endpoint. Remove it with `snow app teardown --force --connection <conn> --role HOL_ADMIN`.

## Local development

```bash
npm ci
SNOWFLAKE_CONNECTION_NAME=<conn> SNOWFLAKE_ROLE=HOL_ADMIN SNOWFLAKE_WAREHOUSE=BARCLAYS_WH npm run dev
```

Locally, progress is recorded against your own Snowflake user.
