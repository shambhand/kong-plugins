# Circuit Breaker Kong Custom Plugin

## Overview

The circuit-breaker Kong custom plugin provides circuit-breaker functionality at the API gateway level. It wraps proxy calls in a circuit-breaker pattern to prevent cascading failures when upstream services become unhealthy.

Based on [dream11/kong-circuit-breaker](https://github.com/dream11/kong-circuit-breaker) and [dream11/lua-circuit-breaker](https://github.com/dream11/lua-circuit-breaker).

### How It Works

The plugin implements a state machine with three states:

- **Closed** (normal): Requests pass through. Failures are tracked within a sliding window.
- **Open** (tripped): When failures exceed the threshold, the circuit opens. All requests are immediately rejected with the configured `error_status_code` (default: 599).
- **Half-Open** (recovery): After `wait_duration_in_open_state` seconds, a limited number of requests are allowed through to test if the upstream has recovered.

### Kong Lifecycle Phases

- **access**: Checks circuit state via `_before()`. If open, returns error immediately. Sets request timeout.
- **header_filter**: Records success/failure via `_after()` based on upstream HTTP status (< 500 = success).
- **log**: Logs state changes. Optionally sets metrics in `kong.ctx.shared.logger_metrics` for downstream plugins (e.g., Datadog).
- **init_worker**: Listens for plugin config invalidation events to flush stale circuit breaker objects.

## Dependencies

This plugin requires the `lua-circuit-breaker` library to be deployed as a **separate ConfigMap**. Both must be mounted into the Kong container.

### Deployment Order

```bash
# 1. Deploy the library ConfigMap
helm upgrade --install lua-circuit-breaker oci://ghcr.io/shambhand/helm-charts/lua-circuit-breaker --version 1.0.0 -n kong

# 2. Deploy the plugin ConfigMap
helm upgrade --install circuit-breaker oci://ghcr.io/shambhand/helm-charts/circuit-breaker --version 1.0.0 -n kong
```

## Configuration Reference

### Plugin Parameters

- **window_time** (number, required, default: 10): Sliding window size in seconds for tracking failures
- **min_calls_in_window** (number, required, default: 20): Minimum calls in window before failure calculation starts
- **api_call_timeout_ms** (number, required, default: 2000): Request timeout in milliseconds (timeout = failure)
- **failure_percent_threshold** (number, required, default: 51): Failure percentage to trip the circuit open
- **wait_duration_in_open_state** (number, required, default: 15): Seconds before open state transitions to half-open
- **wait_duration_in_half_open_state** (number, required, default: 120): Seconds before half-open transitions back to closed
- **half_open_max_calls_in_window** (number, required, default: 10): Maximum calls allowed in half-open state
- **half_open_min_calls_in_window** (number, required, default: 5): Minimum calls for half-open failure calculation
- **error_status_code** (number, required, default: 599): HTTP status code returned when circuit is open
- **error_msg_override** (string, optional): Custom error message body when circuit is open
- **response_header_override** (string, optional): Custom Content-Type header on circuit-open response
- **excluded_apis** (string/JSON, required, default: `{"GET_/kong-healthcheck": true}`): JSON map of API identifiers to exclude from circuit breaking
- **set_logger_metrics_in_ctx** (boolean, optional, default: true): Whether to set circuit breaker metrics in `kong.ctx.shared.logger_metrics`

### Notes

- `excluded_apis` must be valid JSON. API identifiers use the format `METHOD_/path` (e.g., `GET_/health`).
- The plugin priority is **920** by default. Override with the `PRIORITY_CIRCUIT_BREAKER` environment variable.

## Implementation Examples

### Enabling Plugin on a Service

```yaml
service:
  name: "sample-httpbin"
  url: "https://httpbin.org"
  routes:
    - name: anything
      protocols: ["http"]
      methods: ["GET"]
      paths: ["/anything"]
      strip_path: false
  plugins:
    - name: "circuit-breaker"
      config:
        window_time: 10
        min_calls_in_window: 20
        api_call_timeout_ms: 2000
        failure_percent_threshold: 51
        wait_duration_in_open_state: 15
        wait_duration_in_half_open_state: 120
        half_open_max_calls_in_window: 10
        half_open_min_calls_in_window: 5
        error_status_code: 503
        error_msg_override: "Service temporarily unavailable"
        response_header_override: "application/json"
        excluded_apis: '{"GET_/kong-healthcheck": true}'
        set_logger_metrics_in_ctx: true
```

### Enabling Plugin on a Specific Route

```yaml
service:
  name: "sample-httpbin"
  url: "https://httpbin.org"
  routes:
    - name: anything
      protocols: ["http"]
      methods: ["GET"]
      paths: ["/anything"]
      strip_path: false
      plugins:
        - name: "circuit-breaker"
          config:
            window_time: 10
            min_calls_in_window: 20
            api_call_timeout_ms: 3000
            failure_percent_threshold: 60
            wait_duration_in_open_state: 30
            error_status_code: 503
```

## Observability

When `set_logger_metrics_in_ctx` is enabled, the plugin writes state change events to `kong.ctx.shared.logger_metrics`. This data can be consumed by logging plugins (e.g., Datadog, New Relic) to emit metrics with tags:

- `upstream:<host>`
- `circuit_breaker:<METHOD_/path>`
- `cb_state:<closed|open|half_open>`

## Source Code

- [Plugin source code](https://github.com/shambhand/kong-plugins/tree/main/kong/plugins/circuit-breaker)
- [lua-circuit-breaker library](https://github.com/shambhand/kong-plugins/tree/main/kong/plugins/lua-circuit-breaker)
- [Helm chart](https://github.com/shambhand/kong-plugins/tree/main/kong/plugins/circuit-breaker/helm)
