# Helm Chart for External Website Gateway

This Helm chart simplifies the process of setting up a gateway for a website hosted externally to your Kubernetes cluster. It includes configurations for creating a Kubernetes Service and an Ingress to efficiently redirect traffic to the external website.

## Features
- Service Creation: Automatically creates a Kubernetes Service to handle traffic within the cluster.
- Ingress Configuration: Sets up an Ingress resource to facilitate traffic redirection to the external website.
- TLS/SSL Support: Optionally includes configurations for setting up TLS/SSL certificates to secure the Ingress communication.

## Manual Install Examples

Create an ingress for a website created outside of the Kubernetes cluster.
Note: This only works if the external website is http
```bash
helm install grafana charts/external-app-lb/v1.0.0 \
--set endpoint.extIP=192.168.93.50 \
--set service.portName=grafana \
--set service.port=80 \
--set service.targetPort=30002 \
--set ingress.hosts[0].host=ext-grafana.xpaceoff.com,ingress.hosts[0].paths[0].path=/,ingress.hosts[0].paths[0].pathType=Prefix
```

Create an ingress for a website created outside of the Kubernetes cluster.
In this example we enabled TLS and issued a certificate with the specified Issuer.
Note: This only works if the external website is http
```bash
helm install grafana charts/external-app-lb/v1.0.0 \
--set endpoint.extIP=192.168.93.50 \
--set service.portName=grafana \
--set service.port=80 \
--set service.targetPort=30002 \
--set ingress.tlsEnabled=true \
--set ingress.issuer=letsencrypt-staging \
--set ingress.hosts[0].host=ext-grafana.xpaceoff.com,ingress.hosts[0].paths[0].path=/,ingress.hosts[0].paths[0].pathType=Prefix
```

Create an ingress for a website created outside of the Kubernetes cluster.
This example is the same as the previous one but in the ingress redirects all http traffic to https.
Note: This only works if the external website is http
```bash
helm install grafana charts/external-app-lb/v1.0.0 \
--set endpoint.extIP=192.168.93.50 \
--set service.portName=grafana \
--set service.port=80 \
--set service.targetPort=30002 \
--set ingress.tlsEnabled=true \
--set ingress.issuer=letsencrypt-staging \
--set ingress.forceHttps=true \
--set ingress.hosts[0].host=ext-grafana.xpaceoff.com,ingress.hosts[0].paths[0].path=/,ingress.hosts[0].paths[0].pathType=Prefix
```
