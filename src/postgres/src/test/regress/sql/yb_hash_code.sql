-- test yb_hash_code as a function
SELECT yb_hash_code(1,2,3);
SELECT yb_hash_code(1,2,'abc'::text);

-- test on unsupported primary key types
SELECT yb_hash_code('asdf');
SELECT yb_hash_code('{"a": {"b":{"c": "foo"}}}'::jsonb);
SELECT yb_hash_code(ARRAY[1,2,3]);

-- test basic filtering on different datatypes with yb_hash_code
CREATE TABLE test_table_int (x INT PRIMARY KEY);
INSERT INTO test_table_int SELECT generate_series(1, 20);
SELECT yb_hash_code(x), x FROM test_table_int;
DROP TABLE test_table_int;

CREATE TABLE test_table_real (x REAL PRIMARY KEY);
INSERT INTO test_table_real SELECT generate_series(1, 20);
SELECT yb_hash_code(x), x FROM test_table_real;
DROP TABLE test_table_real;

CREATE TABLE test_table_double (x DOUBLE PRECISION PRIMARY KEY);
INSERT INTO test_table_double SELECT generate_series(1, 20);
SELECT yb_hash_code(x), x FROM test_table_double;
DROP TABLE test_table_double;

CREATE TABLE test_table_small (x SMALLINT PRIMARY KEY);
INSERT INTO test_table_small SELECT generate_series(1, 20);
SELECT yb_hash_code(x), x FROM test_table_small;
DROP TABLE test_table_small;

CREATE TABLE test_table_text (x TEXT PRIMARY KEY);
INSERT INTO test_table_text SELECT generate_series(800001, 800020);
SELECT yb_hash_code(x), x FROM test_table_text;
DROP TABLE test_table_text;

CREATE TYPE mood AS ENUM ('sad', 'ok', 'happy');
SELECT yb_hash_code('sad'::mood);
SELECT yb_hash_code('happy'::mood);
CREATE TABLE test_table_mood (x mood, y INT, PRIMARY KEY((x,y) HASH));
INSERT INTO test_table_mood VALUES ('sad'::mood, 1), ('happy'::mood, 4), 
('ok'::mood, 4), ('sad'::mood, 34), ('ok'::mood, 23);
SELECT yb_hash_code(x,y), * FROM test_table_mood;
DROP TABLE test_table_mood;
DROP TYPE mood;

-- test basic pushdown on a table with one primary hash key column
CREATE TABLE test_table_one_primary (x INT PRIMARY KEY, y INT);
INSERT INTO test_table_one_primary SELECT i,i FROM generate_series(1, 10000) i;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x) = 10427;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x) = 10427;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x) < 512;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x) < 512 LIMIT 5;

-- this should not be pushed down as (x,y) is not a hash primary key yet
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) < 512;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) < 512 LIMIT 5;

-- pushdown on yb_hash_code(x,y) should work after this index 
-- on (x,y) hash is created
CREATE INDEX test_secondary ON test_table_one_primary ((x, y) HASH);
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) < 512;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) < 512 LIMIT 5;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) = 10;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) = 10;

-- testing with a qualification on yb_hash_code(x) and x
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x) < 512 AND x < 90;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x) < 512 AND x < 90;

-- should not be pushed down as the selectivity of this filter is too high
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) < 60000;

-- should select the more selective index on x
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) < 60000 AND yb_hash_code(x) > 60000;

-- this should not be pushed down as the order of (x,y) is not correct
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM test_table_one_primary WHERE yb_hash_code(y,x) < 512;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(y,x) < 512 LIMIT 7;

-- should not be pushed down as we don't support pushdown on IN filters yet
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE)  SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) IN (1, 200, 326);
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) IN (1, 200, 326);

EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE)  SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) BETWEEN 4 AND 512;
SELECT * FROM test_table_one_primary WHERE yb_hash_code(x, y) BETWEEN 4 AND 512 LIMIT 5;
DROP TABLE test_table_one_primary;

-- testing pushdown where the hash column is of type text
CREATE TABLE text_table (hr text, ti text, tj text, i int, j int, primary key (hr));
INSERT INTO text_table SELECT i::TEXT, i::TEXT, i::TEXT, i, i FROM generate_series(1,10000) i;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM text_table WHERE yb_hash_code(hr) = 30;
SELECT * FROM text_table WHERE yb_hash_code(hr) = 30;

-- pushdown should not occur in this case but it should
-- operate as a normal index expression
CREATE INDEX ybhashtjidx ON text_table (yb_hash_code(tj));
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM text_table WHERE yb_hash_code(tj) = 63;
SELECT * FROM text_table WHERE yb_hash_code(tj) = 63;
DROP INDEX ybhashtjidx;

-- testing pushdown on a secondary index with a text hash column
CREATE INDEX textidx ON text_table (tj);
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM text_table WHERE yb_hash_code(tj) = 63;
SELECT * FROM text_table WHERE yb_hash_code(tj) = 63;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * FROM text_table WHERE yb_hash_code(tj) <= 63;
SELECT * FROM text_table WHERE yb_hash_code(tj) <= 63;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT tj FROM text_table WHERE yb_hash_code(tj) <= 63;
SELECT tj FROM text_table WHERE yb_hash_code(tj) <= 63;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT hr FROM text_table WHERE yb_hash_code(tj) < 63;
SELECT hr FROM text_table WHERE yb_hash_code(tj) < 63;
DROP TABLE text_table;

-- testing on a table with multiple hash key columns on 
-- multiple types
CREATE TABLE test_table_multi_col_key(h1 BIGINT, h2 FLOAT, h3 TEXT, r1 TIMESTAMPTZ, r2 DOUBLE PRECISION, v1 INT, v2  DATE, v3 BOOLEAN, PRIMARY KEY ((h1, h2, h3) HASH, r1, r2));
INSERT INTO test_table_multi_col_key SELECT i::BIGINT, i::FLOAT, i::TEXT, '2018-12-18 04:59:54-08'::TIMESTAMPTZ, i::DOUBLE PRECISION, i::INT, '2016-06-02'::DATE,(i%2)::BOOLEAN FROM generate_series(1, 10000) i;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60;

-- limit and order by
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60 LIMIT 3;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60 LIMIT 3;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60 ORDER BY h1;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60 ORDER BY h1;
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60 ORDER BY h1 LIMIT 3;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60 ORDER BY h1 LIMIT 3;

-- create an index with the same set of primary keys as 
-- the primary index
CREATE INDEX multi_key_index_1 ON test_table_multi_col_key((h1,h2,h3) HASH, r1 ASC, r2 ASC);

-- create other indexes on other columsn that are not 
-- hashed in the primary index
CREATE INDEX multi_key_index_2 ON test_table_multi_col_key((r1, r2, v1) HASH, v3, v2);
CREATE INDEX multi_key_index_3 ON test_table_multi_col_key((r1, r2, v2, v3) HASH, v1);

-- index only scan on multi_key_index
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT h1 from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60;
SELECT h1 from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60;

-- index scan on primary key index
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60;

-- sequential scan as the selectivity of this filter is 
-- high
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60000 LIMIT 10;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3) < 60000 LIMIT 10;

-- testing pushdown where the input to the yb_hash_code
-- does not match any index hash key

-- sequential scan as no index has (h1,h2,h3,v1) as the 
-- hash key
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3,v1) < 60 LIMIT 10;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h2,h3,v1) < 60 LIMIT 10;

-- sequential scan as no index has (h1,h3,h2) as the 
-- hash key
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h3,h2) < 60 LIMIT 10;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(h1,h3,h2) < 60 LIMIT 10;

EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,v3,v2,r2) < 60 LIMIT 10;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,v3,v2,r2) < 60 LIMIT 10;

EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(r2,r1,v1) < 60 LIMIT 10;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(r2,r1,v1) < 60 LIMIT 10;

-- pushdown for multi_key_index_2 and multi_key_index_3
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v1) < 60 LIMIT 10;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v1) < 60 LIMIT 10;

EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) < 60 LIMIT 10;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) < 60 LIMIT 10;

-- cost model tests to make sure that pushdown occurs on the
-- most selective yb_hash_code filter
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) < 600 AND yb_hash_code(h1,h2,h3) < 65500 AND yb_hash_code(r1, r2, v1) > 5500;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) < 600 AND yb_hash_code(h1,h2,h3) < 65500 AND yb_hash_code(r1, r2, v1) > 5500 LIMIT 10;

EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) < 600 AND yb_hash_code(h1,h2,h3) > 65500 AND yb_hash_code(r1, r2, v1) > 5500;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) < 600 AND yb_hash_code(h1,h2,h3) > 65500 AND yb_hash_code(r1, r2, v1) > 5500;

-- all given filters here have very high selectivity so this
-- should be a sequential scan
EXPLAIN (COSTS OFF, TIMING OFF, SUMMARY OFF, ANALYZE) SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) > 600 AND yb_hash_code(h1,h2,h3) < 65500 AND yb_hash_code(r1, r2, v1) > 5500;
SELECT * from test_table_multi_col_key WHERE yb_hash_code(r1,r2,v2,v3) > 600 AND yb_hash_code(h1,h2,h3) < 65500 AND yb_hash_code(r1, r2, v1) > 5500 LIMIT 10;

DROP TABLE test_table_multi_col_key;
