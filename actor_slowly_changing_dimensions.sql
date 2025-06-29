/*Task-3*/

CREATE TABLE actors_history_scd (
    actorid TEXT,
    actor TEXT,
    quality_class TEXT CHECK(quality_class IN ('star', 'good', 'average', 'bad')),
    is_active BOOLEAN,
    start_date DATE NOT NULL,
    end_date DATE,
    is_current BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (actorid, start_date)
);

/*Task-4*/
/*Backfill query to insert data from actors table created*/
INSERT INTO actors_history_scd (actorid, actor, quality_class, is_active, start_date, end_date, is_current)
SELECT 
    actorid,
    actor,
    quality_class,
    is_active,
    TO_DATE(current_year || '-01-01', 'YYYY-MM-DD') AS start_date,
    '2999-01-01' AS end_date,               -- Latest record has NULL end date
    TRUE AS is_current
FROM actors;

Select Count(*) FROM actors_history_scd

/*Task-5*/
WITH current_snapshot AS (
	SELECT 	
		actorid,
		actor,
		quality_class,
		is_active,
		TO_DATE(current_year ||'01-01','YYYY-MM-DD') AS new_start_date
	FROM actors
),
changed_rows AS(
	SELECT 
		cs.actorid,
		cs.actor,
		cs.quality_class,
		cs.is_active,
		cs.new_start_date,
		ah.start_date AS old_start_date
	FROM current_snapshot cs
	JOIN actors_history_scd ah
		ON cs.actorid = ah.actorid AND ah.is_current = TRUE
	WHERE cs.quality_class <> ah.quality_class
		OR cs.is_active <> ah.is_active
),
end_record AS(
/*update previous records to set end_date and is_current to FALSE*/
	UPDATE actors_history_scd ah
	SET 	
		end_date = cr.new_start_date - INTERVAL '1 day',
		is_current = FALSE
	FROM changed_rows cr 
	WHERE ah.actorid = cr.actorid AND ah.start_date = cr.old_start_date
	RETURNING ah.actorid
)
/*Insert New Records*/
INSERT INTO actors_history_scd
SELECT
	cr.actorid,
	cr.actor,
	cr.quality_class,
	cr.is_active,
	cr.new_start_date,
	NULL AS end_date,
	TRUE AS is_current
FROM changed_rows cr