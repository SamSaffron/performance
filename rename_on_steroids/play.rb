require_relative '../rerunner/rerunner'
require 'mini_sql'
require 'pg'

pg_conn = PG.connect(dbname: 'discourse_development')
conn = MiniSql::Connection.get(pg_conn)

conn.exec("drop table if exists testing")
conn.exec("drop table if exists testing_old")

conn.exec("create table testing(a int)")
conn.exec("insert into testing(a) values(1),(2),(3)")


# in migration

conn.exec("alter table testing rename to testing_old")
conn.exec("create view testing as select *, a as new_a from testing")
