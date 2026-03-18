# lantern-rails

Postgres health monitoring for Rails apps. Collects database metrics and sends them to [Lantern](https://uselantern.dev) — a hosted dashboard that scores your database health and surfaces actionable recommendations.

## Installation

Add to your Gemfile:

```ruby
gem "lantern-rails"
```

Then run:

```
bundle install
```

## Setup

1. Generate an API key at [uselantern.dev](https://uselantern.dev)
2. Store the key using one of the options below
3. Create an initializer

### Store your API key

**Option A: Environment variable**

```
LANTERN_API_KEY=lnt_your_key_here
```

**Option B: Rails credentials**

```
bin/rails credentials:edit
```

Flat:
```yaml
lantern_api_key: lnt_your_key_here
```

Or nested:
```yaml
lantern:
  api_key: lnt_your_key_here
```

### Create the initializer

```ruby
# config/initializers/lantern.rb
Lantern::Rails.configure do |config|
  # Match how you stored the key above:
  config.api_key = ENV["LANTERN_API_KEY"]
  # Or: config.api_key = Rails.application.credentials.lantern_api_key
  # Or: config.api_key = Rails.application.credentials.dig(:lantern, :api_key)
end
```

That's it. The collector starts automatically when your Rails app boots in production.

## Configuration

```ruby
Lantern::Rails.configure do |config|
  config.api_key                  = ENV["LANTERN_API_KEY"]
  config.host                     = "https://uselantern.dev"  # default
  config.interval                 = 300                       # seconds, default 5 min
  config.collect_in_environments  = %w[production staging]   # default
end
```

## Deploy tracking

To correlate deploys with health score changes, call this from your deploy pipeline or a Rails initializer that runs after deploy:

```ruby
Lantern::Rails.report_deploy
```

Or pass explicit values:

```ruby
Lantern::Rails.report_deploy(
  git_sha:    ENV["GIT_SHA"],
  git_author: ENV["GIT_AUTHOR"],
  deployer:   "github-actions"
)
```

## What gets collected

Every collection interval, the gem queries your Postgres instance for:

- Buffer and index cache hit ratios
- Unused index count and total size
- Table bloat ratio
- Long-running queries (> 30 seconds)
- Dead tuple counts and vacuum status
- Active connections vs. max_connections
- pg_stat_bgwriter stats_reset timestamp (to detect false positives)

No query text, no table data, no PII. Only aggregate pg_stat_* metrics.

## Requirements

- Ruby >= 3.1
- Rails >= 7.0
- PostgreSQL (any version with pg_stat_statements)

## License

MIT
