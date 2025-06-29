/*TASK-1*/
/*Created an array of Struct for film stats*/
CREATE TYPE film_stats AS (
							film TEXT,
							votes INT,
							rating REAL,
							filmid TEXT						
);

/*Created Table actors to implement cumulative design*/
CREATE TABLE actors (
						actorid TEXT,
						actor TEXT,
						films film_stats[],
						quality_class TEXT CHECK(quality_class IN ('star', 'good', 'average', 'bad')),
						is_active BOOLEAN,
						current_year INT,
						PRIMARY KEY(actorid,current_year)
);

/*Cumulative table generation query*/
/*Task-2*/
WITH today AS (
/*Selecting current year records*/
    SELECT 
        af.actorid,
        af.actor,
        af.film,
        af.votes,
        af.rating,
        af.filmid,
        af.year AS current_year
    FROM actor_films af 
    WHERE af.year = 1991
),
yesterday AS (
/*collecting previous year records*/
    SELECT * 
    FROM actors 
    WHERE current_year = 1990
),
/*calculating avg rating for actor*/
actor_avg_rating AS (
    SELECT    
        actorid,
        AVG(rating) AS avg_rating
    FROM today
    GROUP BY actorid
),
/*using avg rating building a quality class*/
actor_quality_class AS (
    SELECT 
        actorid,
        CASE
            WHEN avg_rating > 8 THEN 'star'
            WHEN avg_rating > 7 THEN 'good'
            WHEN avg_rating > 6 THEN 'average'
            ELSE 'bad'
        END AS quality_class
    FROM actor_avg_rating
),
/*checking if the actor is making movies current year*/
actor_is_active AS (
    SELECT 
        actorid,
        TRUE AS is_active
    FROM today
    GROUP BY actorid
),
/*aggregating the records for actor*/
today_agg AS (
    SELECT 
        actorid,
        MIN(actor) AS actor,
        ARRAY_AGG(ROW(film, votes, rating, filmid)::film_stats) AS new_films,
        1990 AS current_year
    FROM today
    GROUP BY actorid
),
/*preparing the final dataset*/
final_data AS (
    SELECT 
        COALESCE(t.actorid, y.actorid) AS actorid,
        COALESCE(t.actor, y.actor) AS actor,
        CASE
            WHEN y.films IS NULL THEN t.new_films
            WHEN t.new_films IS NOT NULL THEN y.films || t.new_films
            ELSE y.films
        END AS films,
        COALESCE(aqc.quality_class, 'bad') AS quality_class,
        COALESCE(aia.is_active, FALSE) AS is_active,
        COALESCE(t.current_year, y.current_year + 1) AS current_year
    FROM today_agg t
    FULL OUTER JOIN yesterday y ON t.actorid = y.actorid
    LEFT JOIN actor_quality_class aqc ON COALESCE(t.actorid, y.actorid) = aqc.actorid
    LEFT JOIN actor_is_active aia ON COALESCE(t.actorid, y.actorid) = aia.actorid
)
/*Inserting the data into actors table*/
INSERT INTO actors (actorid, actor, films, quality_class, is_active, current_year)
SELECT * FROM final_data
/*if duplicate issue in record resolving it by using conflict*/
ON CONFLICT (actorid, current_year)
DO UPDATE SET
    actor = EXCLUDED.actor,
    films = EXCLUDED.films,
    quality_class = EXCLUDED.quality_class,
    is_active = EXCLUDED.is_active;

SELECT COUNT(*) FROM actors
