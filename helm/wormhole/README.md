# Wormhole Helm Chart

This consolidated Helm chart deploys the complete Wormhole platform, including all services and dependencies required for a production deployment.

## Overview

Wormhole is a secure tunnel and reverse proxy system for exposing HPC applications and services over HTTPS with enterprise authentication. This chart deploys:

- **Token Service** - Authentication token and JWT management
- **Route Registry** - Route registration and validation
- **Holepunch** - Envoy-based authentication gateway and xDS control plane
- **Piko** - WebSocket tunnel bastion
- **PostgreSQL** - Database for Token Service and Route Registry
- **RabbitMQ** - Message broker for Route Registry async tasks
- **NATS** - Message broker for Holepunch caching
- **OAuth2 Proxy** (optional) - Authentication gateway for web access

## Prerequisites

- Kubernetes 1.20+ or OpenShift 4.10+
- Helm 3.8+
- Persistent storage provisioner (for PostgreSQL, NATS, RabbitMQ)
- OAuth/OIDC provider for authentication
- DNS configuration for wildcard domains (if using dynamic routing)

## Installation

### 1. Add Required Helm Repositories

```bash
helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo add oauth2-proxy https://oauth2-proxy.github.io/manifests
helm repo update
```

### 2. Update Dependencies

```bash
cd helm/wormhole
helm dependency update
```

### 3. Create Secrets

The Wormhole platform requires several secrets to be created before deployment:

#### NATS Authentication

```bash
kubectl create secret generic nats-auth \
  --from-literal=username=nats_user \
  --from-literal=password=$(openssl rand -base64 32)
```

#### PostgreSQL

```bash
kubectl create secret generic postgres-secrets \
  --from-literal=username=wormhole \
  --from-literal=password=$(openssl rand -base64 32)
```

#### RabbitMQ

```bash
kubectl create secret generic rabbitmq-secrets \
  --from-literal=username=wormhole \
  --from-literal=password=$(openssl rand -base64 32)
```

#### Token Service

Generate JWT signing keys and create the secret:

```bash
# Clone the wormhole repo and navigate to token-service
cd token-service
uv venv
uv pip install -e .

# Generate JWKS keys
uv run token_service generate-jwks --write-settings --overwrite

# Extract the generated keys from config/settings.local.toml
# Create the secret with the JWT private key and admin credentials
kubectl create secret generic token-service-secrets \
  --from-literal=jwt-private-key="$(cat config/settings.local.toml | grep private_key_pem)" \
  --from-literal=admin-username=admin \
  --from-literal=admin-password=$(openssl rand -base64 32)
```

#### Route Registry

```bash
cd ../route-registry
uv venv
uv pip install -e .

# Generate JWKS keys for Piko JWT issuance
uv run route_registry generate-jwks --write-settings --overwrite

# Create the secret
kubectl create secret generic route-registry-secrets \
  --from-literal=jwt-private-key="$(cat config/settings.local.toml | grep private_key_pem)" \
  --from-literal=admin-username=admin \
  --from-literal=admin-password=$(openssl rand -base64 32)
```

#### OAuth2 Proxy (if enabled)

```bash
kubectl create secret generic oauth2-proxy-secrets \
  --from-literal=client-id=<your-oauth-client-id> \
  --from-literal=client-secret=<your-oauth-client-secret> \
  --from-literal=cookie-secret=$(openssl rand -base64 32)
```

#### Holepunch

```bash
# NATS credentials for Holepunch services
kubectl create secret generic holepunch-secrets \
  --from-literal=nats-username=nats_user \
  --from-literal=nats-password=<same-as-nats-auth-password>
```

### 4. Customize Configuration

Copy the example overlay and customize for your environment:

```bash
cp overlays/values.example.yaml overlays/values.myenv.yaml
```

Edit `overlays/values.myenv.yaml` to configure:

- **Image repositories** - Update to point to your container registry
- **Ingress/Route hostnames** - Set your domain names
- **OAuth/OIDC provider** - Configure your authentication provider
- **Resource limits** - Adjust based on your cluster capacity
- **OpenTelemetry endpoints** - Configure observability if available
- **Storage classes** - Set appropriate storage for your cluster

### 5. Deploy

Deploy using the base values and your custom overlay:

```bash
helm install wormhole . \
  -f values.yaml \
  -f overlays/values.myenv.yaml \
  --create-namespace \
  --namespace wormhole
```

Or upgrade an existing deployment:

```bash
helm upgrade wormhole . \
  -f values.yaml \
  -f overlays/values.myenv.yaml \
  --namespace wormhole
```

## Configuration

### Key Configuration Options

#### Image Configuration

All service images can be customized in the overlay:

```yaml
token-service:
  image:
    repository: ghcr.io/llnl/wormhole-token-service
    tag: "v0.2.0"
    pullPolicy: IfNotPresent
```

#### Authentication

Configure OAuth/OIDC for web UI and API access:

```yaml
token-service:
  config:
    auth:
      authlibOidc:
        url: "https://wormhole.example.com/token-service"
        discoveryUrl: "https://auth.example.com/.well-known/openid-configuration"
      oauthJwt:
        jwksUrl: "https://auth.example.com/oauth/jwks"
```

#### Ingress/Routes

Configure hostnames and TLS:

```yaml
token-service:
  ingress:
    enabled: true
    className: ""
    annotations:
      # For OpenShift
      route.openshift.io/termination: edge
    hosts:
      - host: wormhole.example.com
        paths:
          - path: /token-service
            pathType: Prefix
```

#### Wildcard Routing

Configure wildcard domains for user applications:

```yaml
holepunch:
  wildcardHosts:
    apps: "*.apps.wormhole.example.com"
    services: "*.services.wormhole.example.com"
```

#### Resource Limits

Adjust resources based on expected load:

```yaml
token-service:
  resources:
    requests:
      cpu: 300m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi
```

#### Observability

Configure OpenTelemetry endpoints:

```yaml
token-service:
  config:
    otel:
      tracesExporter: "otlp"
      metricsExporter: "otlp"
      logsExporter: "otlp"
      otlpTracesEndpoint: "http://otel-collector.observability.svc.cluster.local:4317"
```

### Component-Specific Configuration

#### NATS

- **Cluster size**: Default 3 replicas for HA
- **Persistence**: Uses PVC for JetStream file store
- **Resources**: Adjust based on message volume

#### PostgreSQL

- **Image variant**: Choose `upstream` or `redhat`
- **Persistence**: Requires PVC for database storage
- **Credentials**: Provided via `postgres-secrets` secret

#### RabbitMQ

- **Image variant**: Choose `upstream` or `redhat`
- **Celery compatibility**: Includes deprecated queue feature flag
- **Credentials**: Provided via `rabbitmq-secrets` secret

#### Piko

- **JWT authentication**: Validates tunnel connections using Route Registry JWKS
- **Connection persistence**: `disable_disconnect_on_expiry: true` keeps tunnels alive

#### OAuth2 Proxy

- **Optional**: Can be disabled if authentication is handled externally
- **Cookie domain**: Must match your service domain for SSO
- **Whitelist domains**: Configure all subdomain patterns

#### Holepunch

- **Autoscaling**: HPA for both Envoy and auth service
- **Log level**: Set to `debug` for troubleshooting, `info` for production
- **Cacher**: CronJob for hot-caching tokens and routes

## Architecture

```
Browser → OAuth2 Proxy → Holepunch (Envoy + Auth) → Piko Tunnel → Airlock → User Application
                              ↓                           ↓
                        Token Service            Route Registry
                              ↓                           ↓
                          PostgreSQL                  RabbitMQ
                              ↓
                            NATS
```

### Service Dependencies

- **Holepunch** depends on: Token Service (auth), Route Registry (routes), NATS (cache), Piko (tunnels)
- **Route Registry** depends on: Token Service (JWT validation), PostgreSQL (persistence), RabbitMQ (async tasks), Piko (JWT issuance)
- **Token Service** depends on: PostgreSQL (persistence)
- **Piko** depends on: Route Registry (JWKS for tunnel auth)

## Deployment Patterns

### Development/Testing

For development environments, you can reduce resource requirements and disable optional components:

```yaml
# Disable autoscaling
holepunch:
  envoy:
    scaler:
      enabled: false
      minReplicas: 1
  authScaler:
    enabled: false

# Reduce resources
nats:
  config:
    cluster:
      replicas: 1
```

### Production

Production deployments should include:

- Multiple replicas with autoscaling
- Persistent storage with backups
- Resource limits and monitoring
- OAuth2 Proxy for centralized auth
- TLS termination at ingress/route
- OpenTelemetry for observability

### OpenShift

For OpenShift deployments:

```yaml
# Enable OpenShift-specific features
holepunch:
  openshift:
    enabled: true
    route:
      tls:
        termination: edge

# Use RedHat certified images
postgres:
  imageVariant: redhat
  redhat:
    image:
      registry: registry.redhat.io
      repository: rhel9/postgresql-16

rabbitmq:
  imageVariant: redhat
  redhat:
    image:
      registry: registry.redhat.io
      repository: rhel9/rabbitmq-39

# Disable OAuth2 Proxy security context
oauth2-proxy:
  securityContext:
    enabled: false
```

## Post-Installation

### 1. Verify Deployment

```bash
# Check pod status
kubectl get pods -n wormhole

# Check services
kubectl get svc -n wormhole

# Check ingress/routes
kubectl get ingress -n wormhole
# or for OpenShift
oc get routes -n wormhole
```

### 2. Initialize Database

The Token Service and Route Registry will automatically run database migrations on startup.

### 3. Create Admin User

Use the Token Service API or UI to create your first admin user and tokens.

### 4. Configure DNS

Ensure DNS records point to your ingress/route endpoints:

- `wormhole.example.com` → Token Service, Route Registry
- `tunnel.wormhole.example.com` → Piko
- `auth.wormhole.example.com` → OAuth2 Proxy
- `*.apps.wormhole.example.com` → Holepunch (wildcard)

### 5. Test Connectivity

```bash
# Test Token Service health
curl https://wormhole.example.com/token-service/.well-known/jwks.json

# Test Route Registry health
curl https://wormhole.example.com/route-registry/api/v1/healthz

# Test Piko tunnel
curl https://tunnel.wormhole.example.com/healthz
```

## Upgrading

### Standard Upgrade

```bash
helm upgrade wormhole . \
  -f values.yaml \
  -f overlays/values.myenv.yaml \
  --namespace wormhole
```

### Database Migrations

Database migrations run automatically on Pod startup via init containers.

### Rolling Back

```bash
helm rollback wormhole -n wormhole
```

## Troubleshooting

### Pods Not Starting

1. Check pod logs: `kubectl logs -n wormhole <pod-name>`
2. Check events: `kubectl get events -n wormhole --sort-by='.lastTimestamp'`
3. Verify secrets exist: `kubectl get secrets -n wormhole`
4. Check resource quotas: `kubectl describe resourcequota -n wormhole`

### Database Connection Issues

1. Verify PostgreSQL is running: `kubectl get pods -n wormhole | grep postgres`
2. Check credentials: `kubectl get secret postgres-secrets -n wormhole -o yaml`
3. Test connection from service pod:
   ```bash
   kubectl exec -n wormhole deploy/token-service -- \
     psql "postgresql://username:password@postgres:5432/wormhole"
   ```

### Authentication Failures

1. Verify Token Service JWKS is accessible:
   ```bash
   curl https://wormhole.example.com/token-service/.well-known/jwks.json
   ```
2. Check OAuth2 Proxy configuration and credentials
3. Verify OIDC provider discovery URL is accessible
4. Check Holepunch logs for auth errors

### Tunnel Connection Issues

1. Verify Piko is accessible: `curl https://tunnel.wormhole.example.com/healthz`
2. Check Route Registry can issue Piko JWTs
3. Verify JWKS endpoint in Piko configuration matches Route Registry
4. Check firewall rules allow WebSocket connections

### Route Registry Worker Issues

1. Verify RabbitMQ is running and accessible
2. Check worker logs: `kubectl logs -n wormhole deploy/route-registry-worker`
3. Check Celery queue status:
   ```bash
   kubectl exec -n wormhole deploy/route-registry-worker -- celery inspect active
   ```

## Uninstall

```bash
# Remove Helm release
helm uninstall wormhole -n wormhole

# Delete PVCs (if you want to remove data)
kubectl delete pvc -n wormhole --all

# Delete namespace
kubectl delete namespace wormhole
```

## Support

For issues, feature requests, or contributions, please visit:
- GitHub: https://github.com/llnl/wormhole

## License

See the main repository LICENSE file for details.
