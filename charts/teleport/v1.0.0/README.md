## Manual install

```bash
# Example overwriting values
helm install teleport charts/teleport/v1.0.0 \
--set ingress.hostUrl=teleport.test.lan \
--set storage.nfs.hostname=nfsserver.lan \
--set storage.type=NFS \
--set storage.nfs.path="/the/nfs/path" \
--namespace test

# prod
helm install teleport charts/teleport/v1.0.0 --namespace prod

# dev
helm install dev charts/teleport/v1.0.0 --namespace dev
```

## Manual upgrade

```bash
# prod
helm upgrade teleport charts/teleport/v1.0.0 --namespace prod

# dev
helm upgrade dev charts/teleport/v1.0.0 --namespace dev
```

## Manual uninstall

```bash
# prod
helm uninstall teleport

# dev
helm uninstall dev
```
