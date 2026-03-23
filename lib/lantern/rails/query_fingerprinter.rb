module Lantern
  module Rails
    class QueryFingerprinter
      # Normalize SQL into a fingerprint by replacing literal values with placeholders.
      # "SELECT * FROM users WHERE id = 42 AND name = 'Eric'" becomes
      # "SELECT * FROM users WHERE id = $1 AND name = $1"
      def self.fingerprint(sql)
        return "" if sql.nil?

        normalized = sql.dup

        # Replace quoted strings (single-quoted, with escaped quotes handled)
        normalized.gsub!(/'(?:[^'\\]|\\.)*'/, "$1")

        # Replace numeric literals (integers and floats, not part of identifiers)
        normalized.gsub!(/\b\d+(?:\.\d+)?\b/, "$1")

        # Replace IN lists: IN ($1, $1, $1) -> IN ($1)
        normalized.gsub!(/IN\s*\(\s*(\$1(?:\s*,\s*\$1)*)\s*\)/i, "IN ($1)")

        # Collapse whitespace
        normalized.gsub!(/\s+/, " ")
        normalized.strip!

        normalized
      end
    end
  end
end
