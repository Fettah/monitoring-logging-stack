# Traefik v2 to v3 Migration Guide

This guide documents a successful migration from Traefik v2 (Helm chart v27.0.2) to Traefik v3 (Helm chart v33.2.1) performed on a Kubernetes cluster.

## Overview

| Component | Before | After |
|-----------|--------|-------|
| Traefik version | v2.x | v3.x |
| Helm chart | v27.0.2 | v33.2.1 |
| CRD API group | traefik.containo.us | traefik.io |

---

## Breaking Changes

### 1. CRD API Group Change (REQUIRED)

All Traefik CRDs must be updated from `traefik.containo.us` to `traefik.io`.

**Before (v2):**
```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
```

**After (v3):**
```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
```

**Affected resources:**
- IngressRoute
- IngressRouteTCP
- IngressRouteUDP
- Middleware
- MiddlewareTCP
- TraefikService
- TLSOption
- TLSStore
- ServersTransport

### 2. Helm Values Changes

| v2 Value | v3 Value | Notes |
|----------|----------|-------|
| `experimental.kubernetesGateway.gateway.enabled` | `gateway.enabled` | Moved to top level |
| `ingressClass.fallbackApiVersion` | REMOVED | Deprecated in v3 |
| `ports.web.expose` | `ports.web.expose.default` | Structure changed |

### 3. Router Rule Syntax

v3 has a new rule syntax. For backward compatibility, add:

```yaml
core:
  defaultRuleSyntax: v2
```

This allows existing IngressRoutes to work without modification. Remove after migrating rules to v3 syntax.

---

## Zero-Downtime Update Strategy

For DaemonSet deployments, use this strategy to avoid downtime:

```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0  # Don't kill any pods until new one is ready
    maxSurge: 1        # Create new pod first, then kill old pod
```

**How it works:**
1. New Traefik v3 pod starts on the node
2. Kubernetes waits for health checks to pass
3. Only then terminates the old v2 pod
4. Traffic is always served - no interruption

**Alternative (faster but has downtime):**
```yaml
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 2  # Allow 2 nodes without Traefik
    maxSurge: 0        # Kill first, then create
```

---

## Known Issues

### Helm Chart v33.2.1 DaemonSet Bug

The Helm chart template unconditionally renders both `maxSurge` and `maxUnavailable`:

```yaml
# Chart template (problematic):
rollingUpdate:
  maxUnavailable: {{ .rollingUpdate.maxUnavailable }}
  maxSurge: {{ .rollingUpdate.maxSurge }}
```

**Problem:** Kubernetes rejects DaemonSets where both values are non-zero.

**Solution:** Use `maxUnavailable: 0, maxSurge: 1` (zero-downtime) OR verify that your explicit `maxSurge: 0` is respected by testing in staging.

---

## Sample Migrated Values File

```yaml
# Traefik Helm Chart Values - Migrated for v3 (chart v33.2.1)

image:
  registry: your-registry.example.com
  repository: traefik
  tag: v3.6.5

deployment:
  kind: DaemonSet

# Zero-downtime strategy
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1

priorityClassName: your-priority-class

ports:
  web:
    nodePort: 30080
    expose:
      default: true
    proxyProtocol:
      trustedIPs:
        - "10.0.0.0/8"
  websecure:
    nodePort: 30443
    expose:
      default: true
    proxyProtocol:
      trustedIPs:
        - "10.0.0.0/8"

logs:
  general:
    level: INFO
  access:
    enabled: true
    format: json
    fields:
      headers:
        defaultmode: keep

metrics:
  prometheus:
    entryPoint: metrics
  # OR for Datadog:
  # datadog: {}

# CHANGED in v3: moved from experimental.kubernetesGateway
gateway:
  enabled: false

ingressClass:
  enabled: true
  isDefaultClass: true
  name: traefik
  # REMOVED: fallbackApiVersion (deprecated in v3)

providers:
  kubernetesCRD:
    enabled: true
    allowCrossNamespace: true
  kubernetesIngress:
    enabled: true
    ingressClass: traefik
    publishedService:
      enabled: true

ingressRoute:
  dashboard:
    enabled: true
    entryPoints: ["websecure"]

service:
  type: LoadBalancer
  spec:
    loadBalancerClass: service.k8s.aws/nlb
    externalTrafficPolicy: Local
  annotations:
    # Your AWS NLB annotations here

globalArguments:
  - "--api.insecure=true"

additionalArguments:
  - "--providers.kubernetescrd.allowcrossnamespace=true"

# ADDED: Backward compatibility for v2 router rule syntax
core:
  defaultRuleSyntax: v2

resources:
  limits:
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 128Mi
```

---

## Migration Checklist

### Pre-Migration
- [ ] Review all IngressRoutes, Middlewares, and other Traefik CRDs
- [ ] Identify all places using `traefik.containo.us` API group
- [ ] Review current values.yaml for deprecated options
- [ ] Test in staging/dev environment first

### Values File Migration
- [ ] Change `experimental.kubernetesGateway` → `gateway`
- [ ] Remove `ingressClass.fallbackApiVersion`
- [ ] Add `core.defaultRuleSyntax: v2` for backward compatibility
- [ ] Update `ports.*.expose` to `ports.*.expose.default` if needed
- [ ] Set zero-downtime update strategy (`maxUnavailable: 0, maxSurge: 1`)

### CRD Migration
- [ ] Update all IngressRoutes: `traefik.containo.us/v1alpha1` → `traefik.io/v1alpha1`
- [ ] Update all Middlewares: `traefik.containo.us/v1alpha1` → `traefik.io/v1alpha1`
- [ ] Update any other Traefik CRDs (TLSOption, ServersTransport, etc.)

### Helm Chart Update
- [ ] Update chart version from v27.x to v33.x
- [ ] Apply new values file
- [ ] Monitor rollout: `kubectl rollout status daemonset/traefik -n traefik`

### Post-Migration
- [ ] Verify Traefik pods are running: `kubectl get pods -n traefik`
- [ ] Check Traefik version: `kubectl get pods -n traefik -o jsonpath='{.items[0].spec.containers[0].image}'`
- [ ] Test all IngressRoutes are working
- [ ] Check Traefik dashboard (if enabled)
- [ ] Monitor logs for errors: `kubectl logs -n traefik -l app.kubernetes.io/name=traefik`

---

## Troubleshooting

### Error: DaemonSet maxSurge invalid
```
DaemonSet.apps "traefik" is invalid: spec.updateStrategy.rollingUpdate.maxSurge:
Invalid value: may not be set when maxUnavailable is non-zero
```

**Solution:** Use either:
- `maxUnavailable: 0, maxSurge: 1` (zero-downtime)
- `maxUnavailable: N, maxSurge: 0` (allows downtime)

### IngressRoutes not working after upgrade
**Cause:** CRD API group not updated.
**Solution:** Change `traefik.containo.us/v1alpha1` to `traefik.io/v1alpha1`

### 404 errors on path-based routing
**Cause:** Path prefix not stripped before forwarding to backend.
**Solution:** Add StripPrefix middleware:
```yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-prefix
spec:
  stripPrefix:
    prefixes:
      - /your-path
```

---

## References

- [Traefik v2 to v3 Migration Guide](https://doc.traefik.io/traefik/v3.0/migration/v2-to-v3/)
- [Traefik 3.0 GA Migration Blog](https://traefik.io/blog/traefik-3-0-ga-has-landed-heres-how-to-migrate)
- [Helm Chart v33.2.1 values.yaml](https://github.com/traefik/traefik-helm-chart/blob/v33.2.1/traefik/values.yaml)
