require 'pg'
conn = PG::Connection.open(dbname: 'test_db')

conn.async_exec('drop table if exists test_types')

conn.async_exec <<~SQL
  CREATE TABLE test_types (
    "smallint" smallint,
    "int" int,
    "bigint" bigint,
    "decimal" decimal,
    "numeric" numeric,
    "real" real,
    "double" double precision,
    "time" timestamp without time zone,
    "date" date,
    "boolean" boolean,
    "inet" inet,
    "cidr" cidr,
    "macaddr" macaddr,
    "serial" serial,
    "bigserial" bigserial,
    "money" money,
    "bytea" bytea,
    "interval" interval,
    "bit" bit(10),
    "json" json,
    "bool[]" bool[]

  )
SQL

conn.async_exec <<~SQL
INSERT INTO test_types (
  "smallint",
  "int",
  "bigint",
  "decimal",
  "numeric",
  "real",
  "double",
  "time",
  "date",
  "boolean",
  "inet",
  "cidr",
  "macaddr",
  "money",
  "bytea",
  "interval",
  "bit",
  "json",
  "bool[]"
)

VALUES (
  1,
  2,
  3,
  4,
  5.1,
  5.2,
  5.3,
  '1-1-2011 2:22',
  '1-2-2011',
  true,
  '1.2.3.4',
  '255.0.0.0',
  'aa:aa:aa:aa:aa:aa',
  100.2,
  E'\\\\xABCDEF',
  '1 year'::interval,
  B'1010101'::bit(10),
  '{"a" : 77}',
  '{true,false,true}'
)
SQL

conn.type_map_for_results = PG::BasicTypeMapForResults.new conn

conn.async_exec('SELECT * FROM test_types').to_a.first.each do |k,v|
  puts "#{k} #{v.class} #{v}"
end


# sam@ubuntu pg_types % ruby test.rb
# Warning: no type cast defined for type "numeric" with oid 1700. Please cast this type explicitly to TEXT to be safe for future changes.
# Warning: no type cast defined for type "inet" with oid 869. Please cast this type explicitly to TEXT to be safe for future changes.
# Warning: no type cast defined for type "cidr" with oid 650. Please cast this type explicitly to TEXT to be safe for future changes.
# Warning: no type cast defined for type "macaddr" with oid 829. Please cast this type explicitly to TEXT to be safe for future changes.
# Warning: no type cast defined for type "money" with oid 790. Please cast this type explicitly to TEXT to be safe for future changes.
# Warning: no type cast defined for type "interval" with oid 1186. Please cast this type explicitly to TEXT to be safe for future changes.
# Warning: no type cast defined for type "bit" with oid 1560. Please cast this type explicitly to TEXT to be safe for future changes.
# smallint Integer 1
# int Integer 2
# bigint Integer 3
# decimal String 4
# numeric String 5.1
# real Float 5.2
# double Float 5.3
# time Time 2011-01-01 02:22:00 +1100
# date Date 2011-01-02
# boolean TrueClass true
# inet String 1.2.3.4
# cidr String 255.0.0.0/32
# macaddr String aa:aa:aa:aa:aa:aa
# serial Integer 1
# bigserial Integer 1
# money String $100.20
# bytea String ��
# �interval String 1 year
# bit String 1010101000
