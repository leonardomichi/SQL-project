
-- controllo tutte le tabelle
SELECT*
FROM shipments;

SELECT*
FROM carriers;

SELECT*
FROM customers;
-- 1
-- calcolo il numero delle spedizioni e il loro costo rispettivamente 
-- per i clienti che per i corrieri e li ordino in ordine decrescente
SELECT customer_name,
COUNT(shipment_id) n,
 ROUND(SUM(freight_cost_eur)) somma_costo
FROM shipments ship
JOIN customers cus
	ON ship.customer_id=cus.customer_id
GROUP BY cus.customer_id
ORDER BY somma_costo DESC;

SELECT carrier_name, 
COUNT(shipment_id) n,
 ROUND(SUM(freight_cost_eur)) somma_costo
FROM carriers car
JOIN shipments ship
	ON car.carrier_id=ship.carrier_id
GROUP BY car.carrier_id
ORDER BY somma_costo DESC;

-- data cleaning
-- creo una tabella di supporto per customer in modo da non intaccare quella originale
-- e identifico e elimino i nomi duplicati
DROP TABLE IF EXISTS customers2;
CREATE TABLE  customers2 AS SELECT * FROM customers;
SELECT *
FROM (
	SELECT 
	TRIM(customer_name), 
		ROW_NUMBER() OVER (
			PARTITION BY TRIM(customer_name,'. ')
		) AS row_num
	FROM 
		customers2
) duplicates
WHERE 
	row_num > 1;
	
WITH duplicati AS (
	SELECT 
		rowid,
		ROW_NUMBER() OVER (
			PARTITION BY TRIM(customer_name, '. ') 
			ORDER BY customer_name ASC
		) AS row_num
	FROM 
		customers2
)
DELETE FROM customers2
WHERE rowid IN (
	SELECT rowid 
	FROM duplicati 
	WHERE row_num > 1
);
SELECT *
FROM carriers;
--creo una tabella di supporto per carrier in modo da non intaccare quella originale
-- e identifico e elimino i nomi duplicati
DROP TABLE IF EXISTS carriers2;
CREATE TABLE carriers2 AS SELECT * FROM carriers;

WITH duplicati AS (
	SELECT rowid,
		ROW_NUMBER() OVER (
			PARTITION BY SUBSTR(carrier_name || ' ', 1, INSTR(carrier_name || ' ', ' ') - 1)
			ORDER BY LENGTH(carrier_name) ASC
		) AS row_num
	FROM carriers2
)
DELETE FROM carriers2 WHERE rowid IN (SELECT rowid FROM duplicati WHERE row_num > 1);
-- ricongiungo gli id che si riferiscono ai custumers cancellati a quelli rimasti che hanno lo stesso nome
WITH mappatura AS (
	SELECT 
		c_originale.customer_id AS id_vecchio, -- L'ID della tabella originale 'customers'
		c_pulita.customer_id AS id_nuovo       -- L'ID della tabella pulita 'customers2'
	FROM 
		customers c_originale
	JOIN 
		customers2 c_pulita 
		ON RTRIM(c_originale.customer_name, '. ') = RTRIM(c_pulita.customer_name, '. ')
)
UPDATE shipments
SET customer_id = (
    SELECT id_nuovo 
    FROM mappatura 
    WHERE id_vecchio = shipments.customer_id
)
WHERE customer_id IN (
    SELECT id_vecchio 
    FROM mappatura 
    WHERE id_vecchio != id_nuovo
);
-- ricongiungo gli id che si riferiscono ai carriers cancellati a quelli rimasti che hanno lo stesso nome
WITH mappatura2 AS (
	SELECT 
		c_originale.carrier_id AS id_vecchio,
		c_pulito.carrier_id AS id_nuovo
	FROM carriers c_originale
	JOIN carriers2 c_pulito 
		ON SUBSTR(c_originale.carrier_name || ' ', 1, INSTR(c_originale.carrier_name || ' ', ' ') - 1)
		   IS SUBSTR(c_pulito.carrier_name || ' ', 1, INSTR(c_pulito.carrier_name || ' ', ' ') - 1)
)
UPDATE shipments
SET carrier_id = (SELECT id_nuovo FROM mappatura2 WHERE id_vecchio = shipments.carrier_id)
WHERE carrier_id IN (SELECT id_vecchio FROM mappatura2 WHERE id_vecchio != id_nuovo);
-- ricontrollo le classifiche di costi e numero di spedizioni dopo aver aggiornato le tabelle
SELECT customer_name,
COUNT(shipment_id) n,
 ROUND(SUM(freight_cost_eur)) somma_costo
FROM shipments ship
JOIN customers2 cus
	ON ship.customer_id=cus.customer_id
GROUP BY cus.customer_id
ORDER BY somma_costo DESC;

SELECT carrier_name, 
COUNT(shipment_id) n,
 ROUND(SUM(freight_cost_eur)) somma_costo
FROM carriers2 car
JOIN shipments ship
	ON car.carrier_id=ship.carrier_id
GROUP BY car.carrier_id
ORDER BY somma_costo DESC;
-- 2
--distribuzione mode di shipments
SELECT ship.mode, COUNT(*) AS n
FROM shipments ship
GROUP BY mode;
-- distribuzione status di shipments
SELECT status, COUNT(*) AS n
FROM shipments
GROUP BY status;
--distribuzione mode di carriers
SELECT car.mode, COUNT(*) AS n
FROM shipments ship
JOIN carriers2 car 
	ON ship.carrier_id = car.carrier_id
GROUP BY car.mode
ORDER BY n DESC;
--distribuzione incrocista di status e mode 
SELECT
    car.mode,
    COUNT(*) AS n,
    ROUND(100.0 * SUM(CASE WHEN ship.status='Cancelled' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_cancellate,
    ROUND(100.0 * SUM(CASE WHEN ship.status='Delayed'   THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_ritardate
FROM shipments ship
JOIN carriers car ON ship.carrier_id = car.carrier_id
GROUP BY car.mode;
-- 3 
-- confronto mode di carriers con mode di shipment per vedere in quanti e quali casi non corrispondono
SELECT
    ship.mode AS mode_dichiarato,
    car.mode AS mode_reale_carrier,
    car.carrier_name,
    COUNT(*) AS n_spedizioni
FROM shipments ship
JOIN carriers2 car ON ship.carrier_id = car.carrier_id
WHERE ship.mode <> car.mode
GROUP BY 1, 2, 3
ORDER BY n_spedizioni DESC;

SELECT
    SUM(CASE WHEN ship.mode = car.mode THEN 1 ELSE 0 END) AS coerenti,
    SUM(CASE WHEN ship.mode <> car.mode THEN 1 ELSE 0 END) AS incoerenti
FROM shipments ship
JOIN carriers2 car ON ship.carrier_id = car.carrier_id; 
-- controllo anomalie su peso, volume e costo, in particolare se ci sono valori negativi
SELECT *
FROM shipments
WHERE weight_kg <= 0 OR volume_cbm<=0 OR freight_cost_eur<=0;
--controllo anomalia di costo su peso
SELECT shipment_id, customer_id, mode, departure_date, arrival_date,freight_cost_eur, weight_kg, freight_cost_eur/weight_kg
FROM shipments
ORDER BY freight_cost_eur/weight_kg DESC;


 


