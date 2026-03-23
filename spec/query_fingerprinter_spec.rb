require "minitest/autorun"
require_relative "../lib/lantern/rails/query_fingerprinter"

class QueryFingerprinterTest < Minitest::Test
  def fingerprint(sql)
    Lantern::Rails::QueryFingerprinter.fingerprint(sql)
  end

  def test_replaces_integer_literals
    sql = 'SELECT "users".* FROM "users" WHERE "users"."id" = 42 LIMIT 1'
    result = fingerprint(sql)
    assert_includes result, "$1"
    refute_includes result, "42"
    refute_includes result, " 1"
  end

  def test_replaces_string_literals
    sql = "SELECT * FROM users WHERE name = 'Eric Mumbower'"
    result = fingerprint(sql)
    assert_includes result, "$1"
    refute_includes result, "Eric"
  end

  def test_replaces_float_literals
    sql = "SELECT * FROM products WHERE price > 19.99"
    result = fingerprint(sql)
    refute_includes result, "19.99"
  end

  def test_collapses_in_lists
    sql = "SELECT * FROM users WHERE id IN (1, 2, 3, 4, 5)"
    result = fingerprint(sql)
    assert_includes result, "IN ($1)"
    refute_includes result, "$1, $1, $1"
  end

  def test_collapses_whitespace
    sql = "SELECT  *  FROM   users   WHERE   id = 1"
    result = fingerprint(sql)
    refute_includes result, "  "
  end

  def test_handles_nil
    assert_equal "", fingerprint(nil)
  end

  def test_same_query_different_values_produce_same_fingerprint
    sql1 = 'SELECT "orders".* FROM "orders" WHERE "orders"."user_id" = 42'
    sql2 = 'SELECT "orders".* FROM "orders" WHERE "orders"."user_id" = 999'
    assert_equal fingerprint(sql1), fingerprint(sql2)
  end

  def test_different_queries_produce_different_fingerprints
    sql1 = 'SELECT * FROM users WHERE id = 1'
    sql2 = 'SELECT * FROM orders WHERE id = 1'
    refute_equal fingerprint(sql1), fingerprint(sql2)
  end
end
