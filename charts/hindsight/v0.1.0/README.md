Hindsight Helm Chart

## Credentials

Credentials come from a Secret in the install namespace. Either create it from the form (**Credentials Source: Enter values here**) or select an existing one (**Use an existing Secret**).

| Key | Required | Notes |
|---|---|---|
| `HINDSIGHT_API_LLM_API_KEY` | for `openai` provider | API key for the LLM endpoint |

Create the Secret before installing when using an existing one:

```bash
kubectl -n <namespace> create secret generic hindsight-secrets \
  --from-literal=HINDSIGHT_API_LLM_API_KEY='CHANGE_ME'
```

## LLM provider

- **openai**: any OpenAI-compatible endpoint, e.g. LiteLLM (`http://litellm.example.com:4000/v1`). Requires the API key.
- **ollama**: a local Ollama server (`http://ollama.example.com:11434/v1`). No key needed.

## Manual install

Using an existing Secret with LiteLLM:

```bash
helm install hindsight charts/hindsight/v0.1.0 -n <namespace> \
--set secretSource=existing \
--set existingSecret=hindsight-secrets \
--set llm.provider=openai \
--set llm.baseUrl=http://litellm.example.com:4000/v1 \
--set llm.model=gpt-oss-20b \
--set ingress.enabled=true \
--set ingress.tlsEnabled=true \
--set ingress.issuer=letsencrypt-prod \
--set ingress.hostUrl=hindsight.example.com
```

Ollama with NFS storage for the embedded database:

```bash
helm install hindsight charts/hindsight/v0.1.0 -n <namespace> \
--set llm.provider=ollama \
--set llm.baseUrl=http://ollama.example.com:11434/v1 \
--set llm.model=gpt-oss:20b \
--set storage.type=NFS \
--set storage.nfs.hostname=nfs.example.com \
--set storage.nfs.path=/volume1/k8s
```

## Manual uninstall

```bash
helm uninstall hindsight -n <namespace>
```

## Manual upgrade

Use `--reuse-values` so unspecified settings are kept:

```bash
helm upgrade hindsight charts/hindsight/v0.1.0 -n <namespace> --reuse-values \
--set llm.model=gpt-oss-20b
```
