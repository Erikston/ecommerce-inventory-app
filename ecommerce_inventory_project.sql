CREATE DATABASE ecommerce_inv;
USE ecommerce_inv;

CREATE TABLE products (
  product_id INT AUTO_INCREMENT PRIMARY KEY,
  sku VARCHAR(64) NOT NULL UNIQUE,
  product_name VARCHAR(255) NOT NULL,
  category VARCHAR(100) NOT NULL,
  unit_cost DECIMAL(12,2) NOT NULL
);

CREATE TABLE suppliers (
  supplier_id INT AUTO_INCREMENT PRIMARY KEY,
  supplier_name VARCHAR(255) NOT NULL
);

CREATE TABLE purchase_orders (
  po_id INT AUTO_INCREMENT PRIMARY KEY,
  supplier_id INT NOT NULL,
  po_date DATE NOT NULL
);

CREATE TABLE purchase_order_lines (
  po_line_id INT AUTO_INCREMENT PRIMARY KEY,
  po_id INT NOT NULL,
  product_id INT NOT NULL,
  order_qty INT NOT NULL CHECK (order_qty >= 0),
  promised_lead_days INT NOT NULL CHECK (promised_lead_days >= 0)
);

CREATE TABLE receipts (
  receipt_id INT AUTO_INCREMENT PRIMARY KEY,
  po_line_id INT NOT NULL,
  received_qty INT NOT NULL CHECK (received_qty >= 0),
  received_date DATE NOT NULL
);

CREATE TABLE inventory_daily (
  product_id INT NOT NULL,
  inv_date DATE NOT NULL,
  on_hand INT NOT NULL CHECK (on_hand >= 0),
  PRIMARY KEY(product_id, inv_date)
);

CREATE TABLE sales_daily (
  product_id INT NOT NULL,
  sales_date DATE NOT NULL,
  qty_sold INT NOT NULL CHECK (qty_sold >= 0),
  PRIMARY KEY(product_id, sales_date)
);
USE ecommerce_inv;

SET SQL_SAFE_UPDATES = 0;
DELETE FROM sales_daily;

INSERT INTO sales_daily (product_id, sales_date, qty_sold)
SELECT 1 AS product_id,
       d AS sales_date,
       IF(DAYOFWEEK(d) IN (1,7), 6, 4) AS qty_sold
FROM (
  SELECT CURDATE() - INTERVAL 29 DAY + INTERVAL seq DAY AS d
  FROM (
    SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24
    UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29
  ) AS t
) AS dates
UNION ALL
SELECT 2, d, 2
FROM (
  SELECT CURDATE() - INTERVAL 29 DAY + INTERVAL seq DAY AS d
  FROM (
    SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24
    UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29
  ) AS t
) AS dates
UNION ALL
SELECT 3, d, IF(DAYOFWEEK(d) IN (1,7), 2, 1)
FROM (
  SELECT CURDATE() - INTERVAL 29 DAY + INTERVAL seq DAY AS d
  FROM (
    SELECT 0 AS seq UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
    UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
    UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14
    UNION ALL SELECT 15 UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23 UNION ALL SELECT 24
    UNION ALL SELECT 25 UNION ALL SELECT 26 UNION ALL SELECT 27 UNION ALL SELECT 28 UNION ALL SELECT 29
  ) AS t
) AS dates;
SELECT COUNT(*) FROM sales_daily;
USE ecommerce_inv;

-- 30-day avg daily sales
CREATE OR REPLACE VIEW v_avg_daily_sales_30 AS
SELECT
  p.product_id,
  p.sku,
  AVG(sd.qty_sold) AS avg_daily_sales_30
FROM products p
JOIN sales_daily sd ON sd.product_id = p.product_id
WHERE sd.sales_date > DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY p.product_id, p.sku;

-- Latest inventory per product
CREATE OR REPLACE VIEW v_latest_inventory AS
SELECT i.product_id, i.on_hand, i.inv_date
FROM inventory_daily i
JOIN (
  SELECT product_id, MAX(inv_date) AS mx
  FROM inventory_daily
  GROUP BY product_id
) m ON m.product_id = i.product_id AND m.mx = i.inv_date;

-- Stockout days
CREATE OR REPLACE VIEW v_stockout_days AS
SELECT product_id, inv_date
FROM inventory_daily
WHERE on_hand = 0;

-- Coverage gaps
CREATE OR REPLACE VIEW v_coverage_gaps AS
SELECT s.product_id, s.sales_date, s.qty_sold
FROM sales_daily s
LEFT JOIN inventory_daily i
  ON i.product_id = s.product_id AND i.inv_date = s.sales_date
WHERE IFNULL(i.on_hand,0) = 0 AND s.qty_sold > 0;

-- Sell-through 30 days
CREATE OR REPLACE VIEW v_sell_through_30 AS
WITH sales AS (
  SELECT product_id, SUM(qty_sold) AS units_sold_30
  FROM sales_daily
  WHERE sales_date > DATE_SUB(CURDATE(), INTERVAL 30 DAY)
  GROUP BY product_id
)
SELECT
  p.product_id,
  p.sku,
  IFNULL(s.units_sold_30,0) AS units_sold_30,
  IFNULL(li.on_hand,0) AS latest_on_hand,
  CASE
    WHEN IFNULL(s.units_sold_30,0) + IFNULL(li.on_hand,0) = 0 THEN 0
    ELSE ROUND(IFNULL(s.units_sold_30,0) / (IFNULL(s.units_sold_30,0) + IFNULL(li.on_hand,0)), 4)
  END AS sell_through_30
FROM products p
LEFT JOIN sales s ON s.product_id = p.product_id
LEFT JOIN v_latest_inventory li ON li.product_id = p.product_id;

-- Days of supply
CREATE OR REPLACE VIEW v_days_of_supply AS
SELECT
  p.product_id,
  p.sku,
  li.on_hand,
  ads.avg_daily_sales_30,
  CASE WHEN IFNULL(ads.avg_daily_sales_30,0) > 0
       THEN ROUND(li.on_hand / ads.avg_daily_sales_30, 2)
       ELSE NULL
  END AS days_of_supply
FROM products p
LEFT JOIN v_latest_inventory li ON li.product_id = p.product_id
LEFT JOIN v_avg_daily_sales_30 ads ON ads.product_id = p.product_id;

SELECT * FROM v_sell_through_30;
SELECT * FROM v_days_of_supply;

USE ecommerce_inv;

-- Lead times per receipt
CREATE OR REPLACE VIEW v_lead_times AS
SELECT
  pol.product_id,
  DATEDIFF(r.received_date, po.po_date) AS lead_time_days
FROM purchase_order_lines pol
JOIN purchase_orders po ON po.po_id = pol.po_id
JOIN receipts r ON r.po_line_id = pol.po_line_id;

-- Lead time stats
CREATE OR REPLACE VIEW v_lead_time_stats AS
SELECT
  product_id,
  ROUND(AVG(lead_time_days), 2) AS avg_lead_days,
  ROUND(IFNULL(STDDEV_POP(lead_time_days),0), 2) AS sd_lead_days
FROM v_lead_times
GROUP BY product_id;

-- Demand stats 60 days
CREATE OR REPLACE VIEW v_demand_stats_60 AS
SELECT
  p.product_id,
  ROUND(AVG(sd.qty_sold), 4) AS avg_daily_sales_60,
  ROUND(IFNULL(STDDEV_POP(sd.qty_sold),0), 4) AS sd_daily_sales_60
FROM products p
JOIN sales_daily sd ON sd.product_id = p.product_id
WHERE sd.sales_date > DATE_SUB(CURDATE(), INTERVAL 60 DAY)
GROUP BY p.product_id;

-- Params table
CREATE TABLE IF NOT EXISTS params (
  param_name VARCHAR(64) PRIMARY KEY,
  param_value DECIMAL(18,6)
);

INSERT INTO params(param_name, param_value)
VALUES ('z_score', 1.650000),
       ('target_days_cover', 30)
ON DUPLICATE KEY UPDATE param_value = VALUES(param_value);

-- Replenishment: safety stock & reorder point
CREATE OR REPLACE VIEW v_replenishment AS
WITH demand AS (
  SELECT d.product_id,
         IFNULL(d.avg_daily_sales_60,0) AS davg,
         IFNULL(d.sd_daily_sales_60,0) AS dsd
  FROM v_demand_stats_60 d
),
lt AS (
  SELECT l.product_id,
         IFNULL(l.avg_lead_days,0) AS ltavg,
         IFNULL(l.sd_lead_days,0) AS ltsd
  FROM v_lead_time_stats l
),
z AS (
  SELECT param_value AS z FROM params WHERE param_name='z_score'
),
cur AS (
  SELECT product_id, on_hand FROM v_latest_inventory
)
SELECT
  p.product_id,
  p.sku,
  IFNULL(d.davg,0) AS avg_daily_sales,
  IFNULL(d.dsd,0) AS sd_daily_sales,
  IFNULL(l.ltavg,0) AS avg_lead_days,
  IFNULL(l.ltsd,0) AS sd_lead_days,
  IFNULL(c.on_hand,0) AS on_hand,
  (SELECT z FROM z) AS z,
  ROUND(
    SQRT(
      (IFNULL(d.davg,0)*IFNULL(d.davg,0))*(IFNULL(l.ltsd,0)*IFNULL(l.ltsd,0)) +
      (IFNULL(l.ltavg,0))*(IFNULL(d.dsd,0)*IFNULL(d.dsd,0))
    ), 4
  ) AS sigma_lt_demand,
  ROUND(
    (SELECT z FROM z) *
    SQRT(
      (IFNULL(d.davg,0)*IFNULL(d.davg,0))*(IFNULL(l.ltsd,0)*IFNULL(l.ltsd,0)) +
      (IFNULL(l.ltavg,0))*(IFNULL(d.dsd,0)*IFNULL(d.dsd,0))
    )
  , 2) AS safety_stock,
  ROUND(
    (IFNULL(d.davg,0) * IFNULL(l.ltavg,0)) +
    ((SELECT z FROM z) *
      SQRT(
        (IFNULL(d.davg,0)*IFNULL(d.davg,0))*(IFNULL(l.ltsd,0)*IFNULL(l.ltsd,0)) +
        (IFNULL(l.ltavg,0))*(IFNULL(d.dsd,0)*IFNULL(d.dsd,0))
      )
    )
  , 2) AS reorder_point
FROM products p
LEFT JOIN demand d ON d.product_id = p.product_id
LEFT JOIN lt l ON l.product_id = p.product_id
LEFT JOIN cur c ON c.product_id = p.product_id;

-- ABC classification
CREATE OR REPLACE VIEW v_abc AS
WITH usage60 AS (
  SELECT p.product_id, p.sku, p.unit_cost,
         IFNULL(d.avg_daily_sales_60,0) AS avg_daily_sales_60
  FROM products p
  LEFT JOIN v_demand_stats_60 d ON d.product_id = p.product_id
),
acv AS (
  SELECT
    product_id,
    sku,
    unit_cost,
    (avg_daily_sales_60 * 365.0) AS annual_units,
    (unit_cost * (avg_daily_sales_60 * 365.0)) AS annual_consumption_value
  FROM usage60
),
ranked AS (
  SELECT
    a.*,
    SUM(annual_consumption_value) OVER () AS total_acv,
    SUM(annual_consumption_value) OVER (ORDER BY annual_consumption_value DESC) AS cumulative_acv
  FROM acv a
)
SELECT
  product_id,
  sku,
  annual_units,
  annual_consumption_value,
  ROUND(cumulative_acv/NULLIF(total_acv,0), 4) AS cumulative_share,
  CASE
    WHEN cumulative_acv <= 0.70 * total_acv THEN 'A'
    WHEN cumulative_acv <= 0.90 * total_acv THEN 'B'
    ELSE 'C'
  END AS abc_class
FROM ranked
ORDER BY annual_consumption_value DESC;

-- Reorder suggestions
CREATE OR REPLACE VIEW v_reorder_suggestions AS
WITH abc AS (
  SELECT product_id, abc_class FROM v_abc
),
params AS (
  SELECT
    MAX(CASE WHEN param_name='target_days_cover' THEN param_value END) AS target_days
  FROM params
)
SELECT
  r.product_id,
  r.sku,
  IFNULL(a.abc_class,'C') AS abc_class,
  r.avg_daily_sales,
  r.avg_lead_days,
  r.safety_stock,
  r.reorder_point,
  r.on_hand,
  ROUND(p.target_days * r.avg_daily_sales + r.safety_stock, 2) AS desired_stock_level,
  GREATEST(0, CEIL((p.target_days * r.avg_daily_sales + r.safety_stock) - r.on_hand)) AS suggested_order_qty,
  CASE WHEN r.on_hand <= r.reorder_point THEN 'REORDER' ELSE 'OK' END AS action
FROM v_replenishment r
LEFT JOIN abc a ON a.product_id = r.product_id
CROSS JOIN params p
ORDER BY action DESC, abc_class, sku;


SELECT * FROM v_lead_time_stats;
SELECT * FROM v_abc;
SELECT * FROM v_reorder_suggestions;
