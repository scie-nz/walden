# Walden

Walden is a small data lake meant for solitary use. Read more about it on [our website](https://scie.nz/walden).

## Prerequisites

There are a few things you need before you create your Walden deployment:

- You need a Linux environment from which to run the code. The code was tested against Ubuntu 20.04 LTS as well as Arch Linux.
- You need a Kubernetes Cluster. If you don't know what that is, check out [K3s](https://k3s.io/).
- Your Kubernetes cluster needs to have at least 4 nodes (regular PCs are fine), with at least 6GB of RAM. We run this on 4 machines, each with 16 GB RAM. It works.
- You need to install [Helm](https://helm.sh/docs/intro/quickstart/), a Kubernetes templating engine. We use this to generate secrets and handle some minor templating.

## Running Walden

Deploy Walden:
```
git clone https://github.com/scie-nz/walden
cd walden/kube
./deploy.sh # requires Helm and kubectl access to cluster
```

You should see a whole bunch of text resulting from the deploy command. As
long as no obvious errors show up, that's expected.

To check the health of your cluster run:
```
kubectl get pods -n walden
```

(If you're using k3s locally, preface this command like so:
 `k3s kubectl get pods -n walden`)

A healthy deployment looks like this:
```
NAME                               READY   STATUS    RESTARTS   AGE
minio-0                            1/1     Running   0          62s
minio-1                            1/1     Running   0          53s
postgres-0                         1/1     Running   0          62s
minio-2                            1/1     Running   0          40s
trino-worker-86d9484f75-zlwwm      1/1     Running   0          62s
minio-3                            1/1     Running   0          31s
trino-coordinator-8c6bc455-ggsnx   1/1     Running   0          62s
devserver-65d668b5c6-xhr6n         1/1     Running   0          62s
metastore-5bf8c4bddf-rjwh7         1/1     Running   0          62s
```

If something has gone wrong, `kubectl logs [name of pod]` should help
most of the time. If you need to do more debugging because something is failing
but are new to Kubernetes, about now would be a good time to go through
a [tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/).

2. Shell into your devserver:

Assuming the deployment succeeded, you can ssh into the pod corresponding to
your devserver like so (make sure to replace `devserver-6c9fcf987c-9vznj`
with your pod ID from `kubectl get pods -n walden`:
```
$ kubectl exec --stdin --tty -n walden deployment/devserver -- /bin/bash
```

3. Create a test MinIO bucket:

Now that you are logged in to the devserver, you are ready to interact with
your glorious data pond! To do so you first need to create a MinIO bucket,
where you will store your data:
```
devserver# mc alias set walden-minio/ http://minio:9000 $MINIO_ACCESS_KEY_ID $MINIO_ACCESS_KEY_SECRET
Added `walden-minio` successfully.

devserver# mc mb walden-minio/test
Bucket created successfully: `walden-minio/test`
```

Note -- `walden-minio` is an alias to the MinIO deployment created
automatically when we start the devserver. We have created a
bucket called "test".

4. Use Trino to create a schema and a table:

First, run (from the devserver shell):
```
devserver# trino test
```

This command starts a session of the trino CLI with the "test" schema. This
schema does not actually exist in the metastore yet, so we need to create it:
```
trino:test> CREATE SCHEMA IF NOT EXISTS test WITH (location='s3a://test/');
CREATE SCHEMA
```

If you run `SHOW SCHEMAS` you should see:
```
trino:test> SHOW SCHEMAS;
       Schema
--------------------
 default
 information_schema
 test
(3 rows)
```

Now we can create a table and store some data:
```
trino:test> CREATE TABLE dim_foo(bar BIGINT);
CREATE TABLE

trino:test> INSERT INTO dim_foo VALUES 1, 2, 3, 4;
INSERT: 4 rows
```

Assuming everything is working, you should be able to query the stored values:
```
trino:test> SELECT bar FROM dim_foo;
 bar
-----
   1
   2
   3
   4
(4 rows)

Query 20220208_051155_00006_zfgnn, FINISHED, 1 node
Splits: 2 total, 2 done (100.00%)
0.36 [4 rows, 250B] [11 rows/s, 691B/s]
```

## Conclusions

That's it, this is an easy way to get a small data lake working.
This is meant to be a fully functional starting point that can be expanded and customized to fit your needs.
Everything here is provided as-is, so your mileage may vary.
Please report any bugs or issues and we will try to get to them.

## Other Notes/Reference

### Building images using Kaniko

Cheat sheet for building images from within an existing cluster.
This can also be done locally via the Docker CLI or similar.
```
kubectl create secret -n walden docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=[your-docker-username] --docker-password=[your-docker-password]
kubectl apply -f kube-build/templates/kaniko-devserver.yaml
```

After building/pushing new release images, update the default `WALDEN_VERSION` in `kube/deploy.sh`.

### Deploying with custom images

Walden can be deployed with custom images from your registry/organization.

1. Assign registry/org prefix (default `docker.io/scienz`): `export WALDEN_ORG=myregistry.example/myorg`
2. (Optional) Assign tag suffixes (default current `YYYY.mm.dd`):
    - Shared tag across images: `export WALDEN_TAG=1234`
    - Individual image overrides: `export WALDEN_DEVSERVER_TAG=1234 WALDEN_METASTORE_TAG=2345 WALDEN_TRINO_TAG=3456`
2. Build and push images: Run `docker/*/build.sh` and `docker/*/push.sh`
3. Deploy environment using the images: Run `kube/deploy.sh`



