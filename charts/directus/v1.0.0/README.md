Directus Helm Chart

## Manual install

```bash
# Example overwriting values
 helm install directus charts/directus/v1.0.0 \
 --set ingress.enabled = true \
 --set ingress.hostUrl = test.xpaceoff.com \
 --set ingress.tlsEnabled = false \
 --set ingress.forceHttps = true \
 --set envVars.directus.adminEmail = test@email.com \
 --set envVars.directus.adminPassword = emailPass \
 --set envVars.directus.key = randomKey \
 --set envVars.directus.secret = randomSecret \
 --set envVars.directus.dbClient = mysql \
 --set envVars.directus.dbHost = dbHostname \
 --set envVars.directus.dbPort = dbPort \
 --set envVars.directus.dbDatabase = dbName \
 --set envVars.directus.dbUser = dbUser \
 --set envVars.directus.dbPass = dbPass \
 --set envVars.directus.emailTransport = smtp \
 --set envVars.directus.emailSmtpHost = smtpHostname \
 --set envVars.directus.emailSmtpPort = smtpPort \
 --set envVars.directus.emailSmtpIgnoreTls = true\
 --set storage.nfs.hostname = nfsHostname \
 --set storage.nfs.path = pathInNfsServer
 # --set ingress.issuer = \


# prod
helm install directus charts/directus/v1.0.0
```

## Manual uninstall

```bash
helm uninstall directus
```

## Manual upgrade

```bash
helm upgrade directus charts/directus/v1.0.0
```

