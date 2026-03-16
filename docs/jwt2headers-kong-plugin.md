# JWT2Headers Kong Custom Plugin

## Overview

The jwt2headers Kong custom plugin extracts claims from a JWT (JSON Web Token) in the Authorization header and injects them as upstream request headers. This is useful when your backend microservices need user context or other token claims without validating the JWT themselves.

### Use Cases

- **Identity propagation**: Pass user email, roles, or groups to upstream services as HTTP headers
- **API key extraction**: Extract an API key claim from the JWT and set it as the `x-api-key` header
- **Claim-based routing**: Inject claims as headers that downstream services or other plugins can use for routing decisions

### Key Features

- Extracts JWT from the Authorization header (supports Bearer prefix)
- Parses claims from the JWT payload
- Filters claims based on inclusion/exclusion patterns
- Converts claim values to strings (including JSON encoding for objects/arrays)
- Sets headers using either custom mapping or a default naming convention with a configurable prefix

## Configuration Reference

### Plugin Parameters

- **name** (string, required): `"jwt2headers"`
- **config.claims_to_include** (array of strings, default: `["*"]`): List of claims to include. Use `"*"` to include all claims.
- **config.claims_to_exclude** (array of strings, default: `["iat", "exp", "jti", "ver", "auth_time"]`): Claims to exclude. Takes precedence over inclusions.
- **config.custom_headers** (map of string to string, default: `{}`): Map of claim names to custom header names.
- **config.header_prefix** (string, default: `"x-"`): Prefix for auto-generated header names.

### Configuration Notes

1. **Claims Filtering**:
   - Use `claims_to_include` to specify which claims should be converted to headers
   - Use `claims_to_exclude` to prevent specific claims from being included
   - Exclusions take precedence over inclusions, even when using the wildcard `"*"`

2. **Header Naming**:
   - Use `custom_headers` to map specific claims to custom header names
   - Use `header_prefix` to set a prefix for automatically generated header names
   - Default naming: `<header_prefix><lowercase_claim_name>` (e.g., `x-sub`, `x-role`)

## Implementation Examples

### Example 1: Specific Claims with Custom Headers

```yaml
plugins:
  - name: jwt2headers
    config:
      claims_to_include:
        - "sub"
        - "access_role"
        - "app_groups"
      claims_to_exclude:
        - "exp"
        - "iat"
        - "auth_time"
      custom_headers:
        sub: "X-User-Email"
        access_role: "X-User-Role"
        app_groups: "X-App-Groups"
      header_prefix: "x-"
```

### Example 2: Include All Claims with Default Settings

```yaml
plugins:
  - name: jwt2headers
    config:
      claims_to_include: ["*"]
      claims_to_exclude:
        - "exp"
        - "iat"
        - "auth_time"
        - "jti"
```

### Example 3: Simple Single Claim Extraction

Extract just the `api-key` claim and set it as a header with the default prefix:

```yaml
plugins:
  - name: jwt2headers
    service: 'sample-httpbin'
    config:
      claims_to_include: ["api-key"]
```

## Helm Chart Deployment

This plugin is packaged as a Helm chart that creates a Kubernetes ConfigMap containing the plugin's Lua code. See the [helm chart](https://github.com/shambhand/kong-plugins/tree/main/kong/plugins/jwt2headers/helm) for details.

```bash
helm install jwt2headers oci://ghcr.io/shambhand/helm-charts/jwt2headers --version 1.0.0 -n kong
```
