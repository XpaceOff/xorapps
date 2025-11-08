
Unofficial Pangolin Helm chart

![Pangolin network in kubernetes](./docs/pangolin-net.png)

```bash
# Install example:
helm install pangolin . \
--set-string settings.pangolin.serverSecretKey=SECRET_KEY_HERE \
--set-string settings.traefik.certificatesResolver.email=YOUR_EMAIL \
--set-string ingress.hostDomain="mydomain.com" \
--set-string volumes[0].name=vol-pangolin \
--set-string volumes[0].nfs.path=/volume/cluster/pangolin \
--set-string volumes[0].nfs.server=nas.lan \
--set-string ingress.issuer="letsencrypt-cert-prod" \
--set ingress.tlsEnabled=true \
--set ingress.forceHttps=true \
-n prod

# Uninstall example:
helm uninstall pangolin -n prod
```
