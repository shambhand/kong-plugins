# Kong Custom Plugins

A collection of custom Kong Gateway plugins packaged as Helm charts for Kubernetes deployment. This repository demonstrates how to version, package, and deploy Kong custom plugins using Helm charts and OCI-compatible registries.

## Plugins

| Plugin | Description | Docs |
|--------|-------------|------|
| [jwt2headers](kong/plugins/jwt2headers/) | Extracts JWT claims and injects them as upstream request headers | [Documentation](docs/jwt2headers-kong-plugin.md) |
| [circuit-breaker](kong/plugins/circuit-breaker/) | Circuit-breaker pattern for upstream services at the gateway level | [Documentation](docs/circuit-breaker-kong-plugin.md) |
| [lua-circuit-breaker](kong/plugins/lua-circuit-breaker/) | Lua library dependency for the circuit-breaker plugin | — |

## Repository Structure

```
kong-plugins/
├── .github/workflows/          # GitHub Actions CI/CD pipelines
│   ├── jwt2headers-plugin-release.yml
│   ├── circuit-breaker-plugin-release.yml
│   └── lua-circuit-breaker-lib-release.yml
├── kong/plugins/
│   ├── jwt2headers/            # JWT-to-headers plugin
│   │   ├── handler.lua
│   │   ├── schema.lua
│   │   └── helm/               # Helm chart for packaging
│   ├── circuit-breaker/        # Circuit-breaker plugin
│   │   ├── handler.lua
│   │   ├── schema.lua
│   │   ├── helpers.lua
│   │   └── helm/
│   └── lua-circuit-breaker/    # Lua library (circuit-breaker dependency)
│       ├── lua-circuit-breaker/
│       │   └── *.lua
│       └── helm/
├── spec/                       # Test specifications (Pongo/Busted)
├── docs/                       # Plugin documentation
└── README.md
```

## How It Works

Each plugin's Lua source code is packaged into a Helm chart that creates a Kubernetes **ConfigMap**. When the Kong Helm chart is deployed, it references these ConfigMaps to mount the plugin code into the Kong container at runtime.

### Deployment Flow

```
1. Package plugin code → Helm chart (ConfigMap)
2. Publish Helm chart → OCI registry (GHCR)
3. Install plugin Helm charts → Kubernetes namespace
4. Install Kong Helm chart → References plugin ConfigMaps
```

### Installing Plugins

**Step 1: Install plugin Helm charts**

```bash
# Simple plugin (no library dependency)
helm install jwt2headers oci://ghcr.io/shambhand/helm-charts/jwt2headers --version 1.0.0 -n kong

# Plugin with library dependency
helm install lua-circuit-breaker oci://ghcr.io/shambhand/helm-charts/lua-circuit-breaker --version 1.0.0 -n kong
helm install circuit-breaker oci://ghcr.io/shambhand/helm-charts/circuit-breaker --version 1.0.0 -n kong
```

**Step 2: Configure Kong Helm chart `values.yaml`**

```yaml
plugins:
  configMaps:
    - pluginName: jwt2headers
      name: jwt2headers-configmap
    - pluginName: circuit-breaker
      name: circuit-breaker-configmap

deployment:
  userDefinedVolumes:
    - name: lua-circuit-breaker-lib
      configMap:
        name: lua-circuit-breaker-configmap
  userDefinedVolumeMounts:
    - name: lua-circuit-breaker-lib
      mountPath: /usr/local/share/lua/5.1/lua-circuit-breaker
```

**Step 3: Install Kong**

```bash
helm install kong kong/kong -f values.yaml -n kong
```

## CI/CD

Each plugin has a dedicated GitHub Actions workflow that:

1. Computes a semantic version from git tags
2. Copies Lua source files into the Helm chart directory
3. Lints and templates the Helm chart
4. Packages and pushes the chart to GitHub Container Registry (GHCR) as an OCI artifact
5. Tags the release in Git

Trigger a release via **Actions → workflow_dispatch**.

## Testing

Tests use the [Kong Pongo](https://github.com/Kong/kong-pongo) framework with Busted.

```bash
# Start Pongo shell
pongo shell

# Run all tests
pongo run

# Run specific plugin tests
pongo run spec/plugins/jwt2headers/
pongo run spec/plugins/circuit-breaker/
```

## License

MIT
