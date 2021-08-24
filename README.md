Walden is a small data lake meant for solitary use. Read more about it
on [our website](https://scie.nz/walden).

# Prerequisites

There are a few things you need before you create your Walden deployment:

- You need a Linux environment from which to run the code. The code was
  tested against Ubuntu 20.04 LTS.
- You need a Kubernetes Cluster. If you don't know what that is, check out
  [K3s](https://k3s.io/).
- Your Kubernetes cluster needs to have at least 4 nodes (regular PCs are
  fine), with at least 6GB of RAM. We run this on 4 machines w/ 16 GBs of
  RAM each. It works.
- You need to install [Helm](https://helm.sh/docs/intro/quickstart/), a
  Kubernetes templating engine. We use this to generate secrets.

# Running Walden

1. Deploy Walden:
```
git clone git@github.com:scie-nz/walden.git
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
NAME                         READY   STATUS    RESTARTS   AGE
minio-1                      1/1     Running   0          167m
minio-0                      1/1     Running   0          166m
minio-2                      1/1     Running   0          166m
minio-3                      1/1     Running   0          166m
postgres-7c989d676c-k5ghj    1/1     Running   0          160m
metastore-7786547cd5-2pnht   1/1     Running   0          142m
trino-worker-0               1/1     Running   0          85m
trino-coordinator-0          1/1     Running   0          85m
devserver-6c9fcf987c-9vznj   1/1     Running   0          19m
```

If something has gone wrong, `kubectl logs [name of pod]` should help
most of the time. If you need to do more debugging because something is failing
but are new to Kubernetes, about now would be a good time to go through
a [tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/).

2. SSH into your devserver:

Assuming the deployment succeeded, you can ssh into the pod corresponding to
your devserver like so (make sure to replace `devserver-6c9fcf987c-9vznj`
with your pod ID from `kubectl get pods -n walden`:
```
export DEVSERVER_POD=devserver-6c9fcf987c-9vznj
kubectl -n walden exec --stdin --tty $DEVSERVER_POD -- /bin/bash
```

3. Create a test MinIO bucket:

Now that you are logged in to the devserver, you are ready to interact with
your glorious data pond! To do so you first need to create a MinIO bucket,
where you will store your data:
```
mc alias set walden-minio/ http://minio:9000 $MINIO_ACCESS_KEY_ID $MINIO_ACCESS_KEY_SECRET
mc mb walden-minio/test
```

You should see:
```
Bucket created successfully: `walden-minio/test`
```

Note -- `walden-minio` is an alias to the MinIO deployment created
automatically when we start the devserver. We have created a
bucket called "test".

4. Use Trino to create a schema and a table:

First, run (from the devserver shell):
```
trino test
```

This command starts a session of the trino CLI with the "test" schema. This
schema does not actually exist in the metastore yet, so we need to create it:
```
CREATE SCHEMA IF NOT EXISTS test WITH (location='s3a://test/');
```

If you run `SHOW SCHEMAS` you should see:
```
       Schema
--------------------
 default
 information_schema
 test
(3 rows)
```

Now we can create a table:
```
CREATE TABLE dim_foo(bar BIGINT);
INSERT INTO dim_foo VALUES 1, 2, 3, 4;
SELECT bar FROM dim_foo;
```

Assuming everything is working, you should now see the values:
```
 bar
-----
   1
   2
   3
   4
(4 rows)

Query 20210216_061509_00014_iymzc, FINISHED, 1 node
Splits: 17 total, 17 done (100.00%)
0.26 [4 rows, 0B] [15 rows/s, 0B/s]
```

# Conclusions

That's it, this is an easy way to get a small data lake working. Everything
here is provided as-is, so your mileage may vary. Please report any bugs or
issues and I will try to get to them.

# Building using Kaniko

```
kubectl create secret -n walden docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=[your-docker-username] --docker-password=[your-docker-password]
cd kube-build
bash deploy.sh
```


