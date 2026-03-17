module Lantern
  module Rails
    class Collector
      def collect
        connection = ActiveRecord::Base.connection

        cache    = collect_cache_metrics(connection)
        indexes  = collect_index_metrics(connection)
        bloat    = collect_bloat_metrics(connection)
        queries  = collect_query_metrics(connection)
        vacuum   = collect_vacuum_metrics(connection)
        conns    = collect_connection_metrics(connection)
        git      = GitMetadata.collect

        {
          collected_at: Time.current.iso8601,

          shared_buffer_hit_ratio: cache[:shared_buffer_hit_ratio],
          index_hit_ratio:         cache[:index_hit_ratio],

          unused_index_count:      indexes[:unused_index_count],
          unused_index_size_bytes: indexes[:unused_index_size_bytes],
          stats_reset_at:          indexes[:stats_reset_at],

          estimated_bloat_bytes:   bloat[:estimated_bloat_bytes],
          bloat_ratio:             bloat[:bloat_ratio],

          long_running_query_count:  queries[:long_running_query_count],
          longest_query_duration_ms: queries[:longest_query_duration_ms],

          total_dead_tuples:         vacuum[:total_dead_tuples],
          total_live_tuples:         vacuum[:total_live_tuples],
          tables_needing_vacuum:     vacuum[:tables_needing_vacuum],
          tables_never_vacuumed:     vacuum[:tables_never_vacuumed],
          oldest_vacuum_age_seconds: vacuum[:oldest_vacuum_age_seconds],

          active_connections:     conns[:active_connections],
          max_connections:        conns[:max_connections],
          connection_utilization: conns[:connection_utilization],

          git_sha:     git[:sha],
          git_message: git[:message]
        }
      rescue => e
        ::Rails.logger.error("[Lantern] Collection failed: #{e.message}")
        nil
      end

      private

      def collect_cache_metrics(conn)
        row = conn.select_one(<<~SQL)
          SELECT
            round(
              sum(heap_blks_hit)::numeric /
              nullif(sum(heap_blks_hit) + sum(heap_blks_read), 0) * 100,
              4
            ) AS shared_buffer_hit_ratio,
            round(
              sum(idx_blks_hit)::numeric /
              nullif(sum(idx_blks_hit) + sum(idx_blks_read), 0) * 100,
              4
            ) AS index_hit_ratio
          FROM pg_statio_user_tables
        SQL

        {
          shared_buffer_hit_ratio: row["shared_buffer_hit_ratio"]&.to_f,
          index_hit_ratio:         row["index_hit_ratio"]&.to_f
        }
      end

      def collect_index_metrics(conn)
        row = conn.select_one(<<~SQL)
          SELECT
            count(*)                                               AS unused_index_count,
            coalesce(sum(pg_relation_size(indexrelid)), 0)::bigint AS unused_index_size_bytes,
            (SELECT stats_reset FROM pg_stat_bgwriter)             AS stats_reset_at
          FROM pg_stat_user_indexes
          JOIN pg_index USING (indexrelid)
          WHERE idx_scan = 0
            AND NOT indisprimary
            AND NOT indisunique
        SQL

        {
          unused_index_count:      row["unused_index_count"].to_i,
          unused_index_size_bytes: row["unused_index_size_bytes"].to_i,
          stats_reset_at:          row["stats_reset_at"]
        }
      end

      def collect_bloat_metrics(conn)
        row = conn.select_one(<<~SQL)
          SELECT
            coalesce(
              sum(
                CASE
                  WHEN n_dead_tup > 0 AND (n_live_tup + n_dead_tup) > 0
                  THEN (n_dead_tup::numeric / (n_live_tup + n_dead_tup) * pg_total_relation_size(relid))
                  ELSE 0
                END
              )::bigint,
              0
            ) AS estimated_bloat_bytes,
            coalesce(
              round(
                sum(n_dead_tup)::numeric /
                nullif(sum(n_live_tup + n_dead_tup), 0) * 100,
                2
              ),
              0
            ) AS bloat_ratio
          FROM pg_stat_user_tables
        SQL

        {
          estimated_bloat_bytes: row["estimated_bloat_bytes"].to_i,
          bloat_ratio:           row["bloat_ratio"].to_f
        }
      end

      def collect_query_metrics(conn)
        row = conn.select_one(<<~SQL)
          SELECT
            count(*)                                                                          AS long_running_query_count,
            coalesce(
              max(extract(epoch from now() - query_start) * 1000)::bigint,
              0
            )                                                                                 AS longest_query_duration_ms
          FROM pg_stat_activity
          WHERE state = 'active'
            AND query_start < now() - interval '30 seconds'
            AND query NOT ILIKE '%pg_stat_activity%'
        SQL

        {
          long_running_query_count:  row["long_running_query_count"].to_i,
          longest_query_duration_ms: row["longest_query_duration_ms"].to_i
        }
      end

      def collect_vacuum_metrics(conn)
        row = conn.select_one(<<~SQL)
          SELECT
            coalesce(sum(n_dead_tup), 0)::bigint                                       AS total_dead_tuples,
            coalesce(sum(n_live_tup), 0)::bigint                                       AS total_live_tuples,
            count(*) FILTER (
              WHERE n_dead_tup > n_live_tup * 0.1 AND n_live_tup > 0
            )                                                                           AS tables_needing_vacuum,
            count(*) FILTER (
              WHERE last_vacuum IS NULL AND last_autovacuum IS NULL AND n_live_tup > 0
            )                                                                           AS tables_never_vacuumed,
            coalesce(
              max(extract(epoch from now() - greatest(last_vacuum, last_autovacuum)))::int,
              0
            )                                                                           AS oldest_vacuum_age_seconds
          FROM pg_stat_user_tables
        SQL

        {
          total_dead_tuples:         row["total_dead_tuples"].to_i,
          total_live_tuples:         row["total_live_tuples"].to_i,
          tables_needing_vacuum:     row["tables_needing_vacuum"].to_i,
          tables_never_vacuumed:     row["tables_never_vacuumed"].to_i,
          oldest_vacuum_age_seconds: row["oldest_vacuum_age_seconds"].to_i
        }
      end

      def collect_connection_metrics(conn)
        row = conn.select_one(<<~SQL)
          SELECT
            count(*) FILTER (WHERE state IS NOT NULL)            AS active_connections,
            current_setting('max_connections')::int              AS max_connections,
            round(
              count(*) FILTER (WHERE state IS NOT NULL)::numeric /
              current_setting('max_connections')::numeric * 100,
              2
            )                                                    AS connection_utilization
          FROM pg_stat_activity
          WHERE datname = current_database()
        SQL

        {
          active_connections:     row["active_connections"].to_i,
          max_connections:        row["max_connections"].to_i,
          connection_utilization: row["connection_utilization"].to_f
        }
      end
    end
  end
end
