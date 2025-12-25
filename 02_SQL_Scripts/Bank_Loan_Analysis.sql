
-- ============================================================
-- Project: Bank Loan Analytics
-- Database: MySQL
-- Author: Mohammad Faiz
-- Objective: End-to-End Loan Data Ingestion, Cleaning & KPI Analysis
-- ============================================================


-- ============================================================
-- PHASE 1: DATABASE & RAW DATA INGESTION
-- ============================================================

CREATE DATABASE IF NOT EXISTS bank_loan_analytics;
USE bank_loan_analytics;


-- ------------------------------------------------------------
-- Phase 1 - Block 1: Staging Table
-- Purpose:
--  - Temporarily store raw CSV data
--  - All columns stored as TEXT to avoid load failures
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS bank_loan_staging (
    c1  TEXT, c2  TEXT, c3  TEXT, c4  TEXT, c5  TEXT,
    c6  TEXT, c7  TEXT, c8  TEXT, c9  TEXT, c10 TEXT,
    c11 TEXT, c12 TEXT, c13 TEXT, c14 TEXT, c15 TEXT,
    c16 TEXT, c17 TEXT, c18 TEXT, c19 TEXT, c20 TEXT,
    c21 TEXT, c22 TEXT, c23 TEXT, c24 TEXT, c25 TEXT,
    c26 TEXT, c27 TEXT, c28 TEXT, c29 TEXT, c30 TEXT,
    c31 TEXT, c32 TEXT, c33 TEXT, c34 TEXT
);


-- ------------------------------------------------------------
-- Phase 1 - Block 2: Load CSV into Staging
-- ------------------------------------------------------------

LOAD DATA INFILE
'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/bank_loan_master_clean.csv'
INTO TABLE bank_loan_staging
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;


SELECT COUNT(*) AS staging_row_count FROM bank_loan_staging;
SELECT * FROM bank_loan_staging LIMIT 5;


-- ============================================================
-- PHASE 2: FINAL TABLE Final Table Creation
-- Purpose:
--  - Define correct data types
--  - Create analytics-ready schema
-- ============================================================

DROP TABLE IF EXISTS bank_loan;

CREATE TABLE bank_loan (
    id INT,
    member_id INT,
    loan_amnt DECIMAL(12,2),
    funded_amnt DECIMAL(12,2),
    funded_amnt_inv DECIMAL(12,2),
    term VARCHAR(20),
    int_rate DECIMAL(6,3),
    installment DECIMAL(12,2),
    grade VARCHAR(5),
    sub_grade VARCHAR(5),
    emp_title VARCHAR(255),
    emp_length VARCHAR(50),
    home_ownership VARCHAR(50),
    annual_inc DECIMAL(14,2),
    verification_status VARCHAR(50),
    issue_d VARCHAR(50),
    loan_status VARCHAR(50),
    purpose VARCHAR(100),
    addr_state VARCHAR(10),
    dti DECIMAL(8,2),
    revol_bal DECIMAL(14,2),
    revol_util DECIMAL(8,2),
    total_pymnt DECIMAL(14,2),
    total_rec_prncp DECIMAL(14,2),
    total_rec_int DECIMAL(14,2),
    last_pymnt_d VARCHAR(50),
    last_pymnt_amnt DECIMAL(14,2),
    last_credit_pull_d VARCHAR(50)
);

-- ------------------------------------------------------------
-- Data Migration (Staging → Final)
-- Purpose:
--  - Map correct columns
--  - Clean percentage field (interest rate)
-- ------------------------------------------------------------

INSERT INTO bank_loan
SELECT
    c1, c2, c3, c4, c5,
    c6, REPLACE(c7,'%',''), c8,
    c9, c10, c11, c12, c13,
    c14, c15,
    c16,
    c17, c18, c19,
    c20, c21, c22,
    c23, c24, c25,
    c26,
    c27,
    c28
FROM bank_loan_staging;


SELECT COUNT(*) AS final_table_rows FROM bank_loan;


-- ============================================================
-- PHASE 3: DATA CLEANING & DATE HANDLING
-- ============================================================

SET SQL_SAFE_UPDATES = 0;

UPDATE bank_loan
SET issue_d = NULL
WHERE issue_d IN ('1900-01-00','0','');

UPDATE bank_loan
SET last_pymnt_d = NULL
WHERE last_pymnt_d IN ('1900-01-00','0','');


UPDATE bank_loan
SET issue_d =
    CASE
        WHEN issue_d REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN issue_d ELSE NULL
    END;

UPDATE bank_loan
SET last_pymnt_d =
    CASE
        WHEN last_pymnt_d REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN last_pymnt_d ELSE NULL
    END;

UPDATE bank_loan
SET last_credit_pull_d =
    CASE
        WHEN last_credit_pull_d REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN last_credit_pull_d ELSE NULL
    END;


ALTER TABLE bank_loan
MODIFY issue_d DATE,
MODIFY last_pymnt_d DATE,
MODIFY last_credit_pull_d DATE;


-- ============================================================
-- PHASE 4: Derived Time Features
-- Purpose:
--  - Year & Month trends
--  - Payment gap analysis
-- ============================================================

ALTER TABLE bank_loan
ADD issue_year INT,
ADD issue_month INT,
ADD payment_gap_months INT;

UPDATE bank_loan
SET
    issue_year = YEAR(issue_d),
    issue_month = MONTH(issue_d),
    payment_gap_months = TIMESTAMPDIFF(MONTH, issue_d, last_pymnt_d);


-- ============================================================
-- PHASE 5: KPI & BUSINESS INSIGHTS
-- ============================================================

-- ------------------------------------------------------------
-- KPI 1: Year-wise Loan Amount
-- ------------------------------------------------------------
SELECT
    issue_year,
    COUNT(*) AS total_loans,
    SUM(loan_amnt) AS total_loan_amount,
    AVG(loan_amnt) AS avg_loan_amount
FROM bank_loan
GROUP BY issue_year
ORDER BY issue_year;

-- Insight:
-- Shows loan demand growth and average ticket size over time

-- ------------------------------------------------------------
-- KPI 2: Grade & Subgrade Revolving Balance
-- ------------------------------------------------------------
SELECT
    grade,
    sub_grade,
    SUM(revol_bal) AS total_revol_balance,
    AVG(revol_bal) AS avg_revol_balance
FROM bank_loan
GROUP BY grade, sub_grade
ORDER BY grade, sub_grade;

-- Insight:
-- Higher grades generally carry lower revolving balances (lower risk)

-- ------------------------------------------------------------
-- KPI 3: Verification Status vs Payment
-- ------------------------------------------------------------

SELECT
    verification_status,
    COUNT(*) AS total_customers,
    SUM(total_pymnt) AS total_payment,
    AVG(total_pymnt) AS avg_payment
FROM bank_loan
GROUP BY verification_status;

-- Insight:
-- Verified customers show stronger repayment reliability

-- ------------------------------------------------------------
-- KPI 4: State-wise Loan Status
-- ------------------------------------------------------------

SELECT
    addr_state,
    loan_status,
    COUNT(*) AS loan_count
FROM bank_loan
GROUP BY addr_state, loan_status
ORDER BY addr_state;

-- Insight:
-- Identifies geographic credit risk & default patterns

-- ------------------------------------------------------------
-- KPI 5: Home Ownership vs Repayment Behaviour
-- ------------------------------------------------------------

SELECT
    home_ownership,
    COUNT(*) AS customers,
    AVG(payment_gap_months) AS avg_payment_gap,
    SUM(last_pymnt_amnt) AS total_last_payment
FROM bank_loan
GROUP BY home_ownership;

-- Insight:
-- Home ownership strongly correlates with repayment discipline

-- ============================================================
-- END OF BANK LOAN ANALYTICS SQL SCRIPT
-- ============================================================
