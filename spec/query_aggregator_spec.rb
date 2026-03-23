require "minitest/autorun"
require_relative "../lib/lantern/rails/query_aggregator"

class QueryAggregatorTest < Minitest::Test
  def setup
    @aggregator = Lantern::Rails::QueryAggregator.new
  end

  def test_drain_returns_empty_when_no_requests
    assert_equal [], @aggregator.drain
  end

  def test_drain_clears_buffer
    @aggregator.record_request(
      controller_action: "orders#index",
      queries: { "SELECT * FROM users WHERE id = $1" => { count: 5, sample_sql: "SELECT * FROM users WHERE id = 42" } }
    )

    results = @aggregator.drain
    assert_equal 1, results.size

    # Second drain should be empty
    assert_equal [], @aggregator.drain
  end

  def test_filters_out_non_n_plus_one_queries
    @aggregator.record_request(
      controller_action: "orders#index",
      queries: { "SELECT * FROM users WHERE id = $1" => { count: 1, sample_sql: "..." } }
    )

    results = @aggregator.drain
    assert_equal 0, results.size
  end

  def test_aggregates_across_multiple_requests
    3.times do
      @aggregator.record_request(
        controller_action: "orders#index",
        queries: { "SELECT * FROM users WHERE id = $1" => { count: 10, sample_sql: "SELECT * FROM users WHERE id = 42" } }
      )
    end

    results = @aggregator.drain
    assert_equal 1, results.size

    qp = results.first
    assert_equal "orders#index", qp[:controller_action]
    assert_equal 10.0, qp[:calls_per_request_avg]
    assert_equal 10, qp[:calls_per_request_max]
    assert_equal 3, qp[:requests_sampled]
  end

  def test_sorts_by_severity_descending
    @aggregator.record_request(
      controller_action: "orders#index",
      queries: {
        "SELECT * FROM users WHERE id = $1" => { count: 5, sample_sql: "..." },
        "SELECT * FROM items WHERE order_id = $1" => { count: 20, sample_sql: "..." }
      }
    )

    results = @aggregator.drain
    assert_equal 2, results.size
    assert_equal 20.0, results.first[:calls_per_request_avg]
    assert_equal 5.0, results.last[:calls_per_request_avg]
  end

  def test_keeps_max_across_requests
    @aggregator.record_request(
      controller_action: "orders#index",
      queries: { "SELECT * FROM users WHERE id = $1" => { count: 5, sample_sql: "..." } }
    )
    @aggregator.record_request(
      controller_action: "orders#index",
      queries: { "SELECT * FROM users WHERE id = $1" => { count: 25, sample_sql: "..." } }
    )

    results = @aggregator.drain
    qp = results.first
    assert_equal 15.0, qp[:calls_per_request_avg]
    assert_equal 25, qp[:calls_per_request_max]
  end

  def test_groups_by_controller_action
    @aggregator.record_request(
      controller_action: "orders#index",
      queries: { "SELECT * FROM users WHERE id = $1" => { count: 10, sample_sql: "..." } }
    )
    @aggregator.record_request(
      controller_action: "orders#show",
      queries: { "SELECT * FROM users WHERE id = $1" => { count: 5, sample_sql: "..." } }
    )

    results = @aggregator.drain
    assert_equal 2, results.size
    actions = results.map { |r| r[:controller_action] }
    assert_includes actions, "orders#index"
    assert_includes actions, "orders#show"
  end
end
