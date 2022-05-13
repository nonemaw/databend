set enable_planner_v2 = 1;

select '====SELECT_FROM_NUMBERS====';
select * from numbers(10);

select '====ALIAS====';
select number as a, number + 1 as b from numbers(1);
select number as a, number + 1 as b from numbers(1) group by a, number order by number;

-- Comparison expressions
select '====COMPARISON====';
select * from numbers(10) where number between 1 and 9 and number > 2 and number < 8 and number is not null and number = 5 and number >= 5 and number <= 5;

-- Cast expression
select '====CAST====';
select * from numbers(10) where cast(number as string) = '5';

-- Binary operator
select '====BINARY_OPERATOR====';
select (number + 1 - 2) * 3 / 4 from numbers(1);

-- Functions
select '====FUNCTIONS====';
select sin(cos(number)) from numbers(1);

-- In list
select '====IN_LIST====';
select * from numbers(5) where number in (1, 3);

-- Aggregator operator
select '====AGGREGATOR====';
create table t(a int, b int);
insert into t values(1, 2), (2, 3), (3, 4);
select sum(a) + 1 from t group by a;
select sum(a) from t group by a;
select sum(a) from t;
select count(a) from t group by a;
select count(a) from t;
select count() from t;
select count() from t group by a;
select count(1) from t;
select count(1) from t group by a;
select count(*) from t;
select sum(a) from t group by a having sum(a) > 1;
select sum(a+1) from t group by a+1 having sum(a+1) = 2;
select sum(a+1) from t group by a+1, b having sum(a+1) > 3;
drop table t;

select 1, sum(number) from numbers_mt(1000000);
select count(*) = count(1) from numbers(1000);
select count(1) from numbers(1000);
select sum(3) from numbers(1000);
select count(null) from numbers(1000);

SELECT max(number) FROM numbers_mt (10) where number > 99999999998;
SELECT max(number) FROM numbers_mt (10) where number > 2;

SELECT number%3 as c1, number%2 as c2 FROM numbers_mt(10000) where number > 2 group by number%3, number%2 order by c1,c2;
SELECT number%3 as c1 FROM numbers_mt(10) where number > 2 group by number%3 order by c1;

CREATE TABLE t(a UInt64 null, b UInt32 null, c UInt32) Engine = Fuse;
INSERT INTO t(a,b, c)  SELECT if (number % 3 = 1, null, number) as a, number + 3 as b, number + 4 as c FROM numbers(10);
-- nullable(u8)
SELECT a%3 as a1, count(1) as ct from t GROUP BY a1 ORDER BY a1,ct;

-- nullable(u8), nullable(u8)
SELECT a%2 as a1, a%3 as a2, count(0) as ct FROM t GROUP BY a1, a2 ORDER BY a1, a2;

-- nullable(u8), u64
SELECT a%2 as a1, to_uint64(c % 3) as c1, count(0) as ct FROM t GROUP BY a1, c1 ORDER BY a1, c1, ct;
-- u64, nullable(u8)
SELECT to_uint64(c % 3) as c1, a%2 as a1, count(0) as ct FROM t GROUP BY a1, c1 ORDER BY a1, c1, ct;

drop table t;

-- Inner join
select '====INNER_JOIN====';
create table t(a int);
insert into t values(1),(2),(3);
create table t1(b float);
insert into t1 values(1.0),(2.0),(3.0);
create table t2(c smallint unsigned null);
insert into t2 values(1),(2),(null);

select * from t inner join t1 on t.a = t1.b;
select * from t inner join t2 on t.a = t2.c;
select * from t inner join t2 on t.a = t2.c + 1;
select * from t inner join t2 on t.a = t2.c + 1 and t.a - 1 = t2.c;
select * from t1 inner join t on t.a = t1.b;
select * from t2 inner join t on t.a = t2.c;
select * from t2 inner join t on t.a = t2.c + 1;
select * from t2 inner join t on t.a = t2.c + 1 and t.a - 1 = t2.c;
select count(*) from numbers(1000) as t inner join numbers(1000) as t1 on t.number = t1.number;

-- order by
select '====ORDER_BY====';
SELECT number%3 as c1, number%2 as c2 FROM numbers_mt (10) order by c1 desc, c2 asc;
SELECT number, null from numbers(3) order by number desc;
SELECT number%3 as c1, number%2 as c2 FROM numbers_mt (10) order by c1, number desc;
SELECT SUM(number) AS s FROM numbers_mt(10) GROUP BY number ORDER BY s;
create table t3(a int, b int);
insert into t3 values(1,2),(2,3);
drop table t;
drop table t1;
drop table t2;
drop table t3;

-- Select without from
select '====SELECT_WITHOUT_FROM====';
select 1 + 1;
select to_int(8);
select "new_planner";
select *; -- {ErrorCode 1065}

-- limit
select '=== Test limit ===';
select number from numbers(100) order by number asc limit 10;
select '==================';
select number*2 as number from numbers(100) order by number limit 10;
select '=== Test limit n, m ===';
select number from numbers(100) order by number asc limit 10, 10;
select '==================';
select number-2 as number from numbers(100) order by number asc limit 10, 10;
select '=== Test limit with offset ===';
select number from numbers(100) order by number asc limit 10 offset 10;
select '==============================';
select number/2 as number from numbers(100) order by number asc limit 10 offset 10;
select '=== Test offset ===';
select number from numbers(10) order by number asc offset 5;
select '===================';
select number+number as number from numbers(10) order by number asc offset 5;

set enable_planner_v2 = 0;