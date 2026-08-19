-- ============================================================
-- iGaming User Value & Commercial-Risk Segmentation
-- Business question: which users generate the most stake (value),
-- and which are commercially loss-making for the business (risk)?
-- ============================================================
-- STEP 1  staging table -- raw copy of the source file
-- STEP 2  load the CSV
-- STEP 3  data-quality checks
-- STEP 4  clean, typed bets table
-- STEP 5  load the clean table from staging
-- STEP 6  user-level value + commercial-risk segmentation
-- STEP 7  business summary -- the answer to the question
-- STEP 8  supporting analysis -- by sport and bet type
-- STEP 9  export for the Power BI dashboard
--
-- Source: "Sports Betting Profiling Dataset" (Kaggle), simulated,
-- 100,000 bets / 5,000 users. Columns: bet_id, user_id, bet_type,
-- sport, odds, is_win, stake, gain, GGR (gross gaming revenue).


-- STEP 1 -- raw staging copy, all text columns on purpose --
-- validate first, convert to real types only once the data is trusted
DROP DATABASE IF EXISTS igaming_portfolio;
CREATE DATABASE igaming_portfolio;
USE igaming_portfolio;

CREATE TABLE staging_bets (
    bet_id VARCHAR(20), user_id VARCHAR(20), bet_type VARCHAR(50),
    sport VARCHAR(50), odds VARCHAR(20), is_win VARCHAR(10),
    stake VARCHAR(20), gain VARCHAR(20), ggr VARCHAR(20)
);


-- STEP 2 -- Load te dataset
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/bets.csv'
INTO TABLE staging_bets
FIELDS TERMINATED BY ';' LINES TERMINATED BY '\n' IGNORE 1 ROWS
(bet_id, user_id, bet_type, sport, odds, is_win, stake, gain, ggr);

SELECT COUNT(*) AS rows_loaded FROM staging_bets;  -- expect 100000


-- STEP 3 -- data-quality gate before this feeds any business decision:
-- missing keys, duplicate bets, invalid stakes, and whether GGR
-- is equal to stake minus gain. ("+0" reads the text column as a number.)
SELECT
    SUM(bet_id = '') AS null_bet_id,
    SUM(user_id = '') AS null_user_id,
    (SELECT COUNT(*) FROM (	
			SELECT bet_id FROM staging_bets
            GROUP BY bet_id 
            HAVING COUNT(*) > 1) AS duplicate_bets
            ) AS dup_bet_id_groups,
    MIN(stake+0) AS min_stake,
    MAX(stake+0) AS max_stake,
    SUM(stake+0 <= 0) AS stake_le_0,
    SUM(gain+0 < 0) AS gain_lt_0,
    SUM(ABS((stake+0 - gain+0) - (ggr+0)) > 0.01) AS ggr_mismatch,
    COUNT(DISTINCT user_id) AS distinct_users
FROM staging_bets;

-- category spelling check -- confirms sport/bet_type have no near-duplicates
SELECT sport, COUNT(*) AS n FROM staging_bets GROUP BY sport ORDER BY sport;
SELECT bet_type, COUNT(*) AS n FROM staging_bets GROUP BY bet_type;


-- STEP 4 -- one clean, typed bets table. The source has only two
-- fields (sport, bet type) and no separate user
-- attributes, so a dimensional model (lookup tables + surrogate
-- keys) would add joins without adding analytical value here --
CREATE TABLE bets (
    bet_id VARCHAR(20) PRIMARY KEY,
    user_id INT NOT NULL,
    sport VARCHAR(50) NOT NULL,
    bet_type VARCHAR(20) NOT NULL,
    odds DECIMAL(6,2) NOT NULL,
    is_win TINYINT NOT NULL,
    stake DECIMAL(10,2) NOT NULL,
    gain DECIMAL(10,2) NOT NULL,
    ggr DECIMAL(10,2) NOT NULL  -- = stake - gain, calculated on load
);


-- STEP 5 -- load the validated data with proper types
-- (MySQL converts the text values automatically on insert)
INSERT INTO bets (bet_id, user_id, sport, bet_type, odds, is_win, stake, gain, ggr)
SELECT bet_id, user_id, sport, bet_type, odds,
    CASE WHEN is_win = 'True' THEN 1 ELSE 0 END,
    stake, gain, stake - gain
FROM staging_bets;

-- row count should match staging exactly
SELECT (SELECT COUNT(*) FROM staging_bets) AS staging_rows,
       (SELECT COUNT(*) FROM bets) AS bets_rows,
       (SELECT COUNT(DISTINCT user_id) FROM bets) AS users,
       (SELECT COUNT(DISTINCT sport) FROM bets) AS sports,
       (SELECT COUNT(DISTINCT bet_type) FROM bets) AS bet_types;


-- STEP 6 -- score every user on value and commercial risk
-- value_tier: based on total stake per user. Cutoffs are named
-- below rather than hardcoded in the CASE statement, and were
-- chosen by reviewing how total stake is actually distributed
-- across the user base, then rounding to a sensible VIP->Micro split.
SET @vip_cutoff = 5000;
SET @core_cutoff = 2500;
SET @casual_cutoff = 1000;

-- commercial_risk_flag: flags users who are, on balance, costing
-- the business money (negative GGR). This is a trading/margin
-- question, NOT a responsible-gambling or customer-welfare signal --
-- RG risk needs behavioural data over time (e.g. bet escalation
-- after a loss), which this dataset has no timestamps to support.

-- view_* tables below are calculated summaries (plain tables, not
-- MySQL VIEWs -- a VIEW can't reference the @cutoff variables above)
DROP TABLE IF EXISTS view_user_segments;
CREATE TABLE view_user_segments AS
SELECT user_id, COUNT(*) AS total_bets, SUM(stake) AS total_stake, SUM(ggr) AS company_profit,
    CASE WHEN SUM(stake) >= @vip_cutoff THEN 'VIP'
         WHEN SUM(stake) >= @core_cutoff THEN 'Core'
         WHEN SUM(stake) >= @casual_cutoff THEN 'Casual'
         ELSE 'Micro' END AS value_tier,
    CASE WHEN SUM(ggr) < 0 THEN 'Loss-Making' ELSE 'Profitable' END AS commercial_risk_flag
FROM bets
GROUP BY user_id;


-- STEP 7 -- business summary: the direct answer to the question --
-- how many users, and how much stake/profit, in each Value x Commercial-Risk segment
SELECT value_tier, commercial_risk_flag, COUNT(*) AS n_users,
    ROUND(SUM(total_stake), 2) AS segment_total_stake,
    ROUND(SUM(total_stake) / (SELECT SUM(stake) FROM bets) * 100, 1) AS pct_of_total_stake,
    ROUND(SUM(company_profit), 2) AS segment_company_profit
FROM view_user_segments
GROUP BY value_tier, commercial_risk_flag
ORDER BY FIELD(value_tier, 'VIP','Core','Casual','Micro'), commercial_risk_flag;


-- STEP 8 -- supporting analysis: same value/risk pattern, cut by
-- sport and bet type, to see where it shows up in the product mix
DROP TABLE IF EXISTS view_sport_summary;
CREATE TABLE view_sport_summary AS
SELECT sport, COUNT(*) AS n_bets, ROUND(AVG(stake), 2) AS avg_stake,
    ROUND(SUM(stake), 2) AS total_stake, ROUND(SUM(is_win) / COUNT(*), 3) AS win_rate,
    ROUND(SUM(ggr) / SUM(stake), 4) AS hold_pct
FROM bets
GROUP BY sport;

DROP TABLE IF EXISTS view_bet_type_summary;
CREATE TABLE view_bet_type_summary AS
SELECT bet_type, COUNT(*) AS n_bets, ROUND(AVG(stake), 2) AS avg_stake,
    ROUND(SUM(stake), 2) AS total_stake, ROUND(SUM(is_win) / COUNT(*), 3) AS win_rate,
    ROUND(SUM(ggr) / SUM(stake), 4) AS hold_pct
FROM bets
GROUP BY bet_type;

DROP TABLE IF EXISTS view_segment_summary;
CREATE TABLE view_segment_summary AS
SELECT value_tier, commercial_risk_flag, COUNT(*) AS n_users,
    ROUND(SUM(total_stake), 2) AS segment_total_stake,
    ROUND(SUM(total_stake) / (SELECT SUM(stake) FROM bets) * 100, 1) AS pct_of_total_stake,
    ROUND(SUM(company_profit), 2) AS segment_company_profit
FROM view_user_segments
GROUP BY value_tier, commercial_risk_flag;


-- STEP 9 -- export for the Power BI dashboard 
SELECT 'value_tier','commercial_risk_flag','n_users','segment_total_stake','pct_of_total_stake','segment_company_profit'
UNION ALL
SELECT value_tier, commercial_risk_flag, n_users, segment_total_stake, pct_of_total_stake, segment_company_profit
FROM view_segment_summary
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/vw_segment_summary.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n';

SELECT 'sport','n_bets','avg_stake','total_stake','win_rate','hold_pct'
UNION ALL
SELECT sport, n_bets, avg_stake, total_stake, win_rate, hold_pct
FROM view_sport_summary
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/vw_sport_summary.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n';

SELECT 'bet_type','n_bets','avg_stake','total_stake','win_rate','hold_pct'
UNION ALL
SELECT bet_type, n_bets, avg_stake, total_stake, win_rate, hold_pct
FROM view_bet_type_summary
INTO OUTFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/vw_bet_type_summary.csv'
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' LINES TERMINATED BY '\n';
