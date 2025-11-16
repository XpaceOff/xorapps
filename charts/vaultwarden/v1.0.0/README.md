VaultWarden Helm chart

```bash
# Install example:
helm install vaultwarden-test vaultwarden/v1.0.0 \
--set ingress.enabled=true \
--set ingress.hostUrl="vaultwarden.local" \
--set-string volumes[0].name=vaultwarden-vol \
--set-string volumes[0].nfs.path=/vol/tmp/vaultwarden \
--set-string volumes[0].nfs.server=nas.lan \
--set env.DOMAIN="https://vaultwarden.lan" \
--set env.INVITATIONS_ALLOWED=true \
--set env.SIGNUPS_ALLOWED=false \
--set env.SMTP_HOST="emailserver.lan" \
--set env.SMTP_SECURITY="off" \
--set env.SMTP_FROM="sample@email.com" \
--namespace test

# Uninstall example:
helm uninstall pangolin -n test
```
