# Wormhole

A secure tunnel and reverse proxy system for exposing HPC applications and services over HTTPS with enterprise authentication.

## Overview

Wormhole provides secure, authenticated access to applications running on HPC systems through a combination of tunneling, authentication, and routing components.

### Core Components

- **Token Service** - Authentication token management and JWT issuance
- **Route Registry** - Route registration, validation, and coordination
- **Holepunch** - Envoy-based gateway with external authentication and xDS control plane
- **Airlock** - Local reverse proxy for request validation and forwarding
- **Wormhole CLI (`wh`)** - User-facing tool for opening tunnels
- **Piko** - Tunnel bastion for WebSocket connections (external dependency)

### Supporting Infrastructure

- **PostgreSQL** - Persistent storage for Token Service and Route Registry
- **RabbitMQ** - Asynchronous task queue for Route Registry
- **NATS** - Route cache distribution for Holepunch
- **OAuth2 Proxy** - Optional OAuth2/OIDC integration

## Architecture

### Request Flow

```
User Browser/Client
    ↓
Holepunch (Envoy Gateway + External Auth)
    ↓
Token Service (JWT validation)
    ↓
Piko Tunnel
    ↓
Airlock (local proxy)
    ↓
User Application
```

### Component Dependencies

**Token Service:**
- PostgreSQL (database: `tokenServiceDB`, schema: `tokenServiceUser`)
- Generates and validates JWTs
- Publishes JWKS for validation
- Depends on: PostgreSQL

**Route Registry:**
- PostgreSQL (database: `routeRegistryDB`, schema: `routeRegistryUser`)
- RabbitMQ (async task processing)
- Validates route authorization metadata
- Issues Piko connection JWTs
- Notifies Holepunch of route changes
- Depends on: PostgreSQL, RabbitMQ, Token Service (JWKS), Airlock (authz endpoint)

**Holepunch:**
- NATS (route cache)
- Token Service (JWKS for JWT validation)
- Route Registry (route data)
- OAuth2 Proxy (optional, for OAuth flows)
- Piko (tunnel connections)
- Depends on: NATS, Token Service, Route Registry, OAuth2 Proxy (optional)

**Airlock:**
- Token Service (JWKS for JWT validation)
- Serves `/-/airlock/authz.json` with authorization metadata
- Depends on: Token Service (JWKS)

**Wormhole CLI:**
- Route Registry (route registration)
- Piko (tunnel establishment)
- Airlock (embedded, starts locally)
- Depends on: Route Registry, Piko

## Deployment

### Prerequisites

- Kubernetes 1.24+ or OpenShift 4.12+
- Helm 3.8+
- PersistentVolume provisioner (for databases)

### Quick Start (Kubernetes)

```bash
# Add the required secrets (see "Required Secrets" section)
kubectl create namespace wormhole

# Install with default values
helm install wormhole ./helm/wormhole \
  -n wormhole \
  -f values.yaml
```

The default configuration:
- Uses official PostgreSQL and RabbitMQ images
- Deploys PostgreSQL, RabbitMQ, and NATS
- Creates in-cluster services
- **Works on Kubernetes without modifications**

### OpenShift Deployment

OpenShift requires specific configuration changes due to Security Context Constraints (SCC):

#### Option 1: Use Red Hat Images (Recommended for Development)

```yaml
# overlays/values.openshift.yaml
postgres:
  imageVariant: redhat  # Use Red Hat UBI PostgreSQL image
  # Red Hat image works with OpenShift's restricted-v2 SCC

rabbitmq:
  imageVariant: redhat  # Use Red Hat Hummingbird RabbitMQ image
  # Red Hat image works with OpenShift's restricted-v2 SCC
```

Deploy:
```bash
helm install wormhole ./helm/wormhole \
  -n wormhole \
  -f values.yaml \
  -f overlays/values.openshift.yaml
```

#### Option 2: Use Operators (Recommended for Production)

Disable the built-in databases and use OpenShift operators:

```yaml
# overlays/values.openshift-prod.yaml
postgres:
  enabled: false

rabbitmq:
  enabled: false

token-service:
  dependencies:
    postgres:
      serviceName: "postgres-operator-postgres"
      port: 5432

route-registry:
  dependencies:
    postgres:
      serviceName: "postgres-operator-postgres"
      port: 5432
    rabbitmq:
      serviceName: "amq-broker-hdls-svc"
      port: 5672
```

**Required Operators:**
- Red Hat PostgreSQL Operator or Crunchy PostgreSQL
- Red Hat AMQ Broker Operator

#### OpenShift Custom CA Trust

If your OpenShift cluster uses custom CA certificates:

```yaml
# overlays/values.openshift.yaml
global:
  customCA:
    enabled: true
    configMapName: custom-ca-bundle
    openshift:
      autoInject: true  # Use OpenShift's CA injection
```

Create the ConfigMap (OpenShift will populate it):
```bash
kubectl create configmap custom-ca-bundle \
  --from-literal=ca-bundle.crt="" \
  -n wormhole

kubectl label configmap custom-ca-bundle \
  config.openshift.io/inject-trusted-cabundle=true \
  -n wormhole
```

### Chart Dependencies Summary

| Component | Kubernetes Default | OpenShift Recommendation |
|-----------|-------------------|--------------------------|
| **PostgreSQL** | ✅ Official image | 🔶 Red Hat image OR disable + use operator |
| **RabbitMQ** | ✅ Official image | 🔶 Red Hat image OR disable + use operator |
| **NATS** | ✅ Official image | ✅ Works as-is |

**Why the differences?**
- Official PostgreSQL image expects UID 999; OpenShift assigns random UIDs
- Red Hat PostgreSQL image uses UID 26 + `fix-permissions` for arbitrary UIDs
- Official RabbitMQ image expects UID 999; OpenShift assigns random UIDs
- Red Hat Hummingbird RabbitMQ image uses UID 65532 + group permissions for arbitrary UIDs
- For production OpenShift, operators provide HA, backup, and enterprise support

## Required Secrets

Before deploying, create these secrets in the target namespace:

**Quick Reference:**
- `token-service-secrets` - JWT keys and OAuth credentials
- `route-registry-secrets` - JWT keys, Piko secret, OAuth credentials
- `holepunch-secrets` - NATS credentials and token service URL
- `oauth2-proxy-secrets` - OAuth client and cookie secret (if enabled)
- `postgres-secrets` - Database credentials (optional, chart creates defaults)
- `rabbitmq-secrets` - Message queue credentials (optional, chart creates defaults)
- `nats-auth` - NATS message bus credentials (**required**, no defaults)

### 1. Token Service Secrets

Currently, the admin API credentials are established in the database and must
be established after Token Service and Postgres are launched.

```bash
kubectl create secret generic token-service-secrets \
  -n wormhole \
  --from-literal=DYNACONF_AUTH__jwt__keys__1__private_pem="$(cat private-key.pem)" \
  --from-literal=DYNACONF_AUTH__jwt__keys__1__public_pem="$(cat public-key.pem)" \
  --from-literal=DYNACONF_AUTH__authlib_oidc__client_id="your-client-id" \
  --from-literal=DYNACONF_AUTH__authlib_oidc__session_config__secret_key="$(openssl rand -hex 32)" \
  --from-literal=DYNACONF_AUTH__authlib_oidc__client_secret="your-client-secret"
```

**Required keys:**
- `DYNACONF_AUTH__authlib_oidc__session_config__secret_key` - FastAPI secret key (random 32-byte hex)
- `DYNACONF_AUTH__jwt__1__private_key` - RSA private key for JWT signing
- `DYNACONF_AUTH__jwt__1__public_key` - RSA public key for JWT verification
- `DYNACONF_AUTH__authlib_oidc__client_id` - OAuth/OIDC client ID
- `DYNACONF_AUTH__authlib_oidc__client_secret` - OAuth/OIDC client secret

### 2. Route Registry Secrets

Currently, the admin API credentials are established in the database and must
be established after Route Registry and Postgres are launched.

```bash
kubectl create secret generic route-registry-secrets \
  -n wormhole \
  --from-literal=DYNACONF_AUTH__jwt__keys__1__private_pem="$(cat private-key.pem)" \
  --from-literal=DYNACONF_AUTH__jwt__keys__1__public_pem="$(cat public-key.pem)" \
  --from-literal=DYNACONF_AUTH__authlib_oidc__client_id="your-client-id" \
  --from-literal=DYNACONF_AUTH__authlib_oidc__client_secret="your-client-secret" \
  --from-literal=DYNACONF_AUTH__authlib_oidc__session_config__secret_key="$(openssl rand -hex 32)"
```

**Required keys:**
- `DYNACONF_AUTH__JWT__1__PRIVATE_KEY` - RSA private key for Piko JWT signing
- `DYNACONF_AUTH__JWT__1__PUBLIC_KEY` - RSA public key
- `DYNACONF_AUTH__AUTHLIB_OIDC__CLIENT_ID` - OAuth/OIDC client ID
- `DYNACONF_AUTH__AUTHLIB_OIDC__CLIENT_SECRET` - OAuth/OIDC client secret

### 3. Holepunch Secrets

The registry secrets and token service admin token are set in their respective databases.
Run the following command to create the secret with these placeholder values
and update them once the credentials are added to the database.

```bash
kubectl create secret generic holepunch-secrets \
  -n wormhole \
  --from-literal=HOLEPUNCH_TOKEN_SERVICE_ADMIN="your-admin-token" \
  --from-literal=HOLEPUNCH_REGISTRY_USERNAME="admin" \
  --from-literal=HOLEPUNCH_REGISTRY_PASSWORD="your-admin-password"
```

**Required keys:**
- `HOLEPUNCH_TOKEN_SERVICE_ADMIN` - Token Service admin token for subtokens
- `HOLEPUNCH_REGISTRY_USERNAME` - Route Registry admin username
- `HOLEPUNCH_REGISTRY_PASSWORD` - Route Registry admin password

### 4. OAuth2 Proxy Secrets (if enabled)

```bash
kubectl create secret generic oauth2-proxy-secrets \
  -n wormhole \
  --from-literal=client-id="your-oauth-client-id" \
  --from-literal=client-secret="your-oauth-client-secret" \
  --from-literal=cookie-secret="$(openssl rand -base64 32 | head -c 32)"
```

**Required keys:**
- `client-id` - OAuth2/OIDC client ID
- `client-secret` - OAuth2/OIDC client secret
- `cookie-secret` - Cookie encryption secret (must be exactly 16, 24, or 32 characters)

**Cookie secret generation (must be exactly 16, 24, or 32 characters):**
```bash
# 32 characters (recommended)
openssl rand -base64 32 | head -c 32

# 24 characters
openssl rand -base64 32 | head -c 24

# 16 characters
openssl rand -base64 32 | head -c 16

# Alternative: Generate alphanumeric string of exact length
cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 32
```

**Note:** The cookie secret must be exactly 16, 24, or 32 **characters** (bytes) for AES encryption. Commands like `openssl rand -hex 32` produce 64 characters (too long) and `openssl rand -base64 32` produces 44 characters (also too long).

### 5. Infrastructure Secrets

These secrets are required for PostgreSQL, RabbitMQ, and NATS. The chart creates default database secrets, but for production you should create your own:

```bash
# PostgreSQL credentials
kubectl create secret generic postgres-secrets \
  -n wormhole \
  --from-literal=username="wormhole" \
  --from-literal=password="$(openssl rand -hex 16)" \
  --from-literal=postgres-password="$(openssl rand -hex 16)" \
  --from-literal=token-service-username="tokenServiceUser" \
  --from-literal=token-service-password="$(openssl rand -hex 16)" \
  --from-literal=route-registry-username="routeRegistryUser" \
  --from-literal=route-registry-password="$(openssl rand -hex 16)"

# RabbitMQ credentials
kubectl create secret generic rabbitmq-secrets \
  -n wormhole \
  --from-literal=username="rabbit" \
  --from-literal=password="$(openssl rand -hex 16)" \
  --from-literal=erlang-cookie="$(openssl rand -hex 32)"

# NATS credentials
kubectl create secret generic nats-auth \
  -n wormhole \
  --from-literal=username="nats_user" \
  --from-literal=password="$(openssl rand -hex 16)"
```

Then reference them in values:
```yaml
postgres:
  auth:
    existingSecret: postgres-secrets

rabbitmq:
  auth:
    existingSecret: rabbitmq-secrets

# Note: NATS secret name is hardcoded in values.yaml as 'nats-auth'
# No additional configuration needed - just create the secret
```

## Configuration

### Key Configuration Options

**Global Settings:**
```yaml
global:
  nodeSelector: {}
  tolerations: []
  affinity: {}
  
  # Custom CA trust (for OpenShift or corporate environments)
  customCA:
    enabled: false
    configMapName: custom-ca-bundle
```

**Database Configuration:**
```yaml
postgres:
  enabled: true
  imageVariant: official  # or "redhat" for OpenShift
  persistence:
    enabled: true
    size: 8Gi
  
rabbitmq:
  enabled: true
  imageVariant: official  # or "redhat" for OpenShift
  persistence:
    enabled: true
    size: 8Gi
```

**Service Configuration:**
```yaml
token-service:
  enabled: true
  replicaCount: 1
  ingress:
    enabled: true
    hosts:
      - host: token-service.example.com
        paths:
          - path: /token-service
            pathType: Prefix

route-registry:
  enabled: true
  replicaCount: 1
  worker:
    replicaCount: 1
  ingress:
    enabled: true
    hosts:
      - host: route-registry.example.com
```

**Holepunch Wildcard Routing:**
```yaml
holepunch:
  wildcardHosts:
    wormhole: "*.wormhole.example.com"
  ingress:
    enabled: true
    tls:
      enabled: true
```

See `values.yaml` for complete configuration options.

## Development

### Testing Helm Charts

```bash
# Render templates locally
helm template wormhole ./helm/wormhole -f values.yaml

# Test with OpenShift settings
helm template wormhole ./helm/wormhole \
  -f values.yaml \
  --set postgres.imageVariant=redhat \
  --set rabbitmq.imageVariant=redhat

# Validate chart
helm lint ./helm/wormhole
```

## Troubleshooting

### PostgreSQL Init Issues

If PostgreSQL initialization fails, check:
```bash
# View init logs
kubectl logs -n wormhole wormhole-postgres-0 -c postgresql

# Check if databases were created
kubectl exec -it -n wormhole wormhole-postgres-0 -- \
  psql -U wormhole -d postgres -c "\l"

# Check if schemas exist
kubectl exec -it -n wormhole wormhole-postgres-0 -- \
  psql -U wormhole -d tokenServiceDB -c "\dn"
```

### RabbitMQ Clustering Issues

```bash
# Check RabbitMQ logs
kubectl logs -n wormhole wormhole-rabbitmq-0

# Check cluster status
kubectl exec -it -n wormhole wormhole-rabbitmq-0 -- \
  rabbitmqctl cluster_status
```

### Holepunch Route Issues

```bash
# Check route cache
kubectl logs -n wormhole -l app.kubernetes.io/name=holepunch -c holepunch-cacher

# Check xDS control plane
kubectl logs -n wormhole -l app.kubernetes.io/name=holepunch -c holepunch-xds

# View current routes
kubectl exec -it -n wormhole deploy/wormhole-holepunch-admin -- \
  curl http://localhost:8082/api/v1/state/ctls
```

### OpenShift Permission Issues

If pods fail to start on OpenShift:
```bash
# Check SCC assignment
oc describe pod <pod-name> -n wormhole | grep scc

# Verify should be "restricted-v2"
# If not, check securityContext settings

# For PostgreSQL and RabbitMQ with Red Hat images, ensure:
postgres:
  imageVariant: redhat

rabbitmq:
  imageVariant: redhat
```

## Production Considerations

### High Availability

For production deployments:

1. **Use external databases** - Managed PostgreSQL and RabbitMQ
2. **Increase replica counts** - Scale horizontally
   ```yaml
   token-service:
     replicaCount: 3
   route-registry:
     replicaCount: 2
     worker:
       replicaCount: 3
   ```
3. **Enable autoscaling** - For Holepunch
   ```yaml
   holepunch:
     envoy:
       scaler:
         enabled: true
         maxReplicas: 10
   ```
4. **Configure resource limits** - Set appropriate requests/limits
5. **Set up monitoring** - OpenTelemetry exporters configured by default

### Backup and Recovery

**PostgreSQL:**
- Use operator-provided backup solutions (Crunchy, CloudNativePG)
- Or configure pg_dump schedules via CronJobs

**Configuration Backup:**
```bash
# Export current values
helm get values wormhole -n wormhole > wormhole-values-backup.yaml

# Backup secrets
kubectl get secrets -n wormhole -o yaml > wormhole-secrets-backup.yaml
```

### Monitoring

Services expose OpenTelemetry metrics by default:
```yaml
# Configure OTLP endpoints
token-service:
  config:
    otel:
      tracesExporter: otlp
      otlpTracesEndpoint: "http://otel-collector:4317"

route-registry:
  config:
    otel:
      tracesExporter: otlp
      otlpTracesEndpoint: "http://otel-collector:4317"
```

## Support

For issues, feature requests, or contributions, please visit:
- GitHub: https://github.com/llnl/wormhole

## License

See the main repository LICENSE file for details.
