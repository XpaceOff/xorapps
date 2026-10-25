LiteLLM Helm Chart

## Manual install

```bash
helm install litellm charts/litellm/v0.1.0 \
--set ingress.enabled=true \
--set ingress.tlsEnabled=true \
--set ingress.issuer=letsencrypt-prod \
--set ingress.hostUrl=litellm.example.com \
--set envVars.litellm.masterKey=your-master-key \
--set envVars.litellm.saltKey=your-salt-key \
--set envVars.litellm.databaseUrl="postgresql://litellm:password@db:5432/litellm"
```

## Manual uninstall

```bash
helm uninstall litellm
```

## Manual upgrade

Use `--reuse-values` so unspecified settings (such as the database URL) are kept:

```bash
helm upgrade litellm charts/litellm/v0.1.0 --reuse-values \
--set envVars.litellm.masterKey=your-new-master-key
```
