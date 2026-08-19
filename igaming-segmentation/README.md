# iGaming User Value & Commercial-Risk Segmentation

A SQL + BI portfolio project analyzing 100,000 simulated sports bets from 5,000 users, to answer a core commercial question: **which users generate the most value, and which are actually losing the business money?**

## Business Question

Which user segments generate the most stake (value), and which are commercially loss-making for the business (risk)? These are two different questions that get conflated if you only look at one score — a high-value user can still be a loss-making one.

## Data

- Source: "Sports Betting Profiling Dataset" (Kaggle), simulated data
- 100,000 bets across 5,000 users
- Columns: bet_id, user_id, bet_type, sport, odds, is_win, stake, gain, GGR (gross gaming revenue)

## Tech Stack

- **MySQL** — staging, data-quality checks, cleaning, and business-logic scoring (see `full_analysis.sql`)
- **Metabase** — dashboarding layer, connected directly to the MySQL database

## Pipeline (see `full_analysis.sql`)

1. Load raw CSV into an untyped staging table
2. Run data-quality checks (nulls, duplicates, invalid stakes, GGR consistency)
3. Build a clean, typed `bets` table
4. Score every user on:
   - **Value tier** — based on total stake (VIP / Core / Casual / Micro)
   - **Commercial risk flag** — Loss-Making if a user's total company profit is negative
5. Summarize by segment, sport, and bet type
6. Export summary views for dashboarding

## Key Finding

VIP and Core "Loss-Making" users — under 14% of the user base — account for nearly 80% of all money lost across every loss-making segment. Meanwhile, "Profitable" VIPs are the single most valuable group per person, averaging over double the profit of a Profitable Core user. Same label, opposite outcome — which is exactly why value and risk need to be scored separately, not collapsed into one number.

Full breakdown and supporting analysis (by sport and bet type) in [`RESULTS.md`](./RESULTS.md).

## Dashboard

See `screenshots/` for the Metabase dashboard — KPI summary, the value × risk segment breakdown (table + chart), sport-level volume and margin, and an interactive sport filter.

## Important Caveat

"Loss-Making" here is a **margin metric**, not a player-welfare signal. It flags users the business has paid out more to than they've staked overall — it says nothing about whether that betting behavior is healthy for the individual. Real responsible-gambling risk needs behavioral data over time (e.g. bet escalation after a loss), which this dataset has no timestamps to support.
