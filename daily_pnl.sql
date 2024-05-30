WITH joined_data AS (
    SELECT 
        m.TRADEDATE,
        m.SECID,
        m.CLOSE,
        CASE
            WHEN d.DIRECTION <> 'BUY'  THEN COALESCE(-d.NUMBER_OF_SHARES,0)
            ELSE COALESCE(d.NUMBER_OF_SHARES,0)
        END AS NUMBER_OF_SHARES,
        
        CASE
            WHEN d.DIRECTION <> 'SELL'  THEN COALESCE(-d.TOTAL_VOLUME,0)
            ELSE COALESCE(d.TOTAL_VOLUME,0)
        END AS TOTAL_VOLUME,
        COALESCE(-d.BROKER_COMMISSIONS,0) BROKER_COMMISSIONS,
        COALESCE(-d.EXCHANGE_COMMISSIONS,0) EXCHANGE_COMMISSIONS
        
    FROM 
        moexdata m
    LEFT JOIN 
        deals d 
    ON 
        DATE(m.TRADEDATE) = DATE(d.TRADEDATE) AND m.SECID = d.SECID
),
cumulative_sums AS (
    SELECT
        TRADEDATE,
        SECID,
        NUMBER_OF_SHARES,
        SUM(NUMBER_OF_SHARES) OVER (ORDER BY TRADEDATE) AS cumulative_number_of_shares,
        SUM(NUMBER_OF_SHARES) OVER (ORDER BY TRADEDATE) * CLOSE AS NPV,
        SUM(TOTAL_VOLUME) OVER (ORDER BY TRADEDATE) AS CASH_BALANCE,
        LAG(CLOSE) OVER (PARTITION BY SECID ORDER BY TRADEDATE) AS PREVIOUS_CLOSE,
        CLOSE,
        TOTAL_VOLUME as CASH_FLOW,
        BROKER_COMMISSIONS,
        EXCHANGE_COMMISSIONS
    FROM
        joined_data
)
SELECT 
    TRADEDATE,
    SECID,
    cumulative_number_of_shares,
    CLOSE,
    PREVIOUS_CLOSE,
    CASH_FLOW,
    CASH_BALANCE,
    cumulative_number_of_shares * CLOSE as NPV,
    COALESCE(LAG(NPV) OVER (PARTITION BY SECID ORDER BY TRADEDATE),0) AS PREVIOUS_NPV,
    BROKER_COMMISSIONS,
    EXCHANGE_COMMISSIONS,
    CASH_FLOW + (cumulative_number_of_shares * CLOSE - COALESCE(LAG(NPV) OVER (PARTITION BY SECID ORDER BY TRADEDATE),0)) + BROKER_COMMISSIONS + EXCHANGE_COMMISSIONS AS PnL

    
FROM 
    cumulative_sums where  DATE(TRADEDATE) > '2024-05-24' and SECID in (select distinct SECID from DEALS);




