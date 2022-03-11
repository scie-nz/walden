# Walden

Walden is a small data lake meant for solitary use. Read more about it on [our website](https://scie.nz/walden).

## Prerequisites

There are a few things you need before you create your Walden deployment:

- You need a Linux environment from which to run the code. The code was tested against Ubuntu 20.04 LTS as well as Arch Linux.
- You need a Kubernetes Cluster. If you don't know what that is, check out [K3s](https://k3s.io/).
- Your Kubernetes cluster needs to have at least 4 nodes (regular PCs are fine), with at least 6GB of RAM. We run this on 4 machines, each with 16 GB RAM. It works.
- You need to install [Helm](https://helm.sh/docs/intro/quickstart/), a Kubernetes templating engine. We use this to generate secrets and handle some minor templating.

## Running Walden

### Deploy Walden

```
git clone https://github.com/scie-nz/walden
cd walden/kube

# requires Helm and kubectl access to cluster:
./deploy.sh values-default.yaml
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
devserver-65d668b5c6-s62m7         1/1     Running   0          49s
metastore-8696bf6b46-455qx         1/1     Running   0          49s
superset-worker-69cd7c966-pwsp8    1/1     Running   0          49s
superset-postgres-0                1/1     Running   0          48s
metastore-postgres-0               1/1     Running   0          48s
superset-66fb584c7d-wc8c4          2/2     Running   0          48s
trino-coordinator-8c6bc455-w2qdw   1/1     Running   0          48s
trino-worker-86d9484f75-7j8cw      1/1     Running   0          47s
superset-redis-0                   1/1     Running   0          47s
minio-0                            1/1     Running   0          47s
minio-1                            1/1     Running   0          36s
minio-2                            1/1     Running   0          27s
minio-3                            1/1     Running   0          21s
```

By default, Walden expects your cluster to have at least four machines/nodes.
If you don't have four nodes, you may see MinIO pods that are stuck in `Pending`.
You can get things unstuck by manually editing the `minio` StatefulSet and removing
the `affinity` block, allowing multiple MinIO pods to deploy on the same machine:
```
# Edit MinIO StatefulSet, remove affinity block
$ kubectl edit statefulset -n walden minio
```

If something else has gone wrong, `kubectl logs -n walden [name of pod]` should help
most of the time. If you need to do more debugging because something is failing
but are new to Kubernetes, about now would be a good time to go through
a [tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/).

### Use devserver to access Trino CLI

Assuming the deployment succeeded, you can ssh into the `devserver` pod like so:
```
$ kubectl exec -it -n walden deployment/devserver -- /bin/bash
```

The following steps are performed from within the `devserver` pod.

#### Create a MinIO bucket

Now that you are logged in to the devserver, you are ready to interact with your glorious data pond!

Let's start by creating a bucket in MinIO, the object store service that's included in Walden. We will store data in these buckets:
```
devserver# mc alias set walden-minio/ http://minio:9000 $MINIO_ACCESS_KEY_ID $MINIO_ACCESS_KEY_SECRET
Added `walden-minio` successfully.

devserver# mc mb walden-minio/direct
Bucket created successfully: `walden-minio/direct`
```

Note -- `walden-minio` is an alias to the MinIO deployment created automatically when we start the devserver. We have created a bucket called "direct".

#### Use Trino to create a schema and table in MinIO

First, run the following command from the devserver shell. This starts a `trino-cli` session with the `direct` schema against the `hive` data storage provided by Walden.
```
devserver# trino direct
```

We will use this schema to talk directly to the MinIO storage. The `direct` schema does not actually exist in the Hive metastore yet, so we need to create it:
```
trino:direct> CREATE SCHEMA IF NOT EXISTS direct WITH (location='s3a://direct/');
CREATE SCHEMA
```

If you run `SHOW SCHEMAS` you should see:
```
trino:direct> SHOW SCHEMAS;
       Schema
--------------------
 default
 direct
 information_schema
(3 rows)
```

Now we can create a table and store some data:
```
trino:direct> CREATE TABLE dim_foo(bar BIGINT);
CREATE TABLE

trino:direct> INSERT INTO dim_foo VALUES 1, 2, 3, 4;
INSERT: 4 rows
```

Assuming everything is working, you should be able to query the stored values:
```
trino:direct> SELECT bar FROM dim_foo;
 bar
-----
   1
   2
   3
   4
(4 rows)
```

Now we can press `Ctrl+D` to exit the Trino console session, and look at the files created in the underlying MinIO bucket we created earlier:
```
trino:direct> ^D

devserver# mc ls -r walden-minio/direct
[2022-03-11 06:22:24 UTC]     0B STANDARD dim_foo/
[2022-03-11 06:21:42 UTC]   250B STANDARD 20220311_062141_00005_26e8n_9d96d247-6da3-49f9-a537-b0bc897879b9
```

We can clean up our test data by deleting the table and then the schema:
```
devserver# trino direct

trino:direct> DROP TABLE dim_foo;
DROP TABLE
trino:direct> DROP SCHEMA direct;
DROP SCHEMA
trino:direct> ^D

devserver# mc ls walden-minio/direct
<empty>
```

#### Use Alluxio to serve MinIO data

Walden comes packaged with Alluxio, which provides caching and several adapters on multiple backend stores. Alluxio can be used to support other storage types that are not natively supported by Trino, such as external NFS servers.

In this case we will point Alluxio to the `alluxio` bucket that we created earlier. The default Walden configuration in `values.yaml` configures Alluxio to use a MinIO bucket named `alluxio` as its backing storage.

In this case we create a new `alluxio` bucket, then start a new Trino session and create an `alluxio` schema that points to the `alluxio` service:
```
devserver# mc mb walden-minio/alluxio
Bucket created successfully: `walden-minio/alluxio`

devserver# trino alluxio

trino:alluxio> CREATE SCHEMA IF NOT EXISTS alluxio WITH (location='alluxio://alluxio:19998/');
CREATE SCHEMA
```

Again we can check `SHOW SCHEMAS`:
```
trino:alluxio> SHOW SCHEMAS;
       Schema
--------------------
 alluxio
 default
 direct
 information_schema
(3 rows)
```

We create a table and store some data:
```
trino:alluxio> CREATE TABLE dim_bar(baz BIGINT);
CREATE TABLE

trino:alluxio> INSERT INTO dim_bar VALUES 4, 5, 6, 7;
INSERT: 4 rows
```

And finally we can fetch the data back:
```
trino:alluxio> SELECT baz FROM dim_bar;
 baz
-----
   4
   5
   6
   7
(4 rows)
```

Now we can press `Ctrl+D` to exit the Trino session, then use the MinIO CLI to check the contents of the `alluxio` bucket:
```
devserver # mc ls -r walden-minio/alluxio
[2022-03-11 07:17:16 UTC]     0B STANDARD dim_bar/
[2022-03-11 07:23:53 UTC]   253B STANDARD dim_bar/20220311_102351_00139_giawv_ecfd5036-44d3-47da-9f87-6e02e04b8c5b
```

The data can again be cleaned up via trino:
```

devserver# trino alluxio

trino:alluxio> DROP TABLE dim_bar;
DROP TABLE
trino:alluxio> DROP SCHEMA alluxio;
DROP SCHEMA
trino:alluxio> ^D

devserver# mc ls walden-minio/alluxio
<empty>
```

### Explore data with Superset

Superset provides a convienient UI for exploring the data that you've stored in Trino.
Walden includes an instance of Superset that's preconfigured to connect to Trino.

Superset has been configured with a `walden` user and a randomly generated password.

Get the password for logging into Superset:
```
$ kubectl get secret -n walden superset-admin -o 'jsonpath={.data.pass}' | base64 -d && echo
lONGpASSWoRD64HERE
```

Set up a port-forward to access Superset on port `8088`:
```
$ kubectl port-forward -n walden deployment/superset 8088
```

Go to [http://127.0.0.1:8088/](`http://127.0.0.1:8088/`) and log in with user=`walden` and the password you got earlier.

Two Trino databases should have been automatically added to Superset by Walden:
- `walden-trino` has Trino data, including what we added to a `test` schema in earlier steps. The data itself is being stored to Minio in Hive columnar table format, with the Metastore acting as the index.
- `walden-trino-system` has various Trino System statistics like node connectivity that may also be interesting to explore.
In addition to these autoconfigured, you should be able to add other external databases to Superset as well via `Data` > `Databases` in the top menu.

We can start exploring by going to `SQL Lab` > `SQL Editor` in the top menu.
In the SQL Editor view, select the `walden-trino` database, then the `test` schema that we created earlier.
The values we added to this schema earlier should also be visible via Superset.

![Screenshot of Superset UI showing test data](superset.png)

### View the Trino Dashboard

Trino also provides a dashboard UI showing basic activity. Set up a port-forward to access the dashboard on port `8080`:
```
$ kubectl port-forward -n walden deployment/trino-coordinator 8080:80
```

Go to [http://127.0.0.1:8080](`http://127.0.0.1:8080`) and log in with any value for the username (it doesn't matter).

![Screenshot of Trino Dashboard](trino.png)

## Conclusions

That's it, this is an easy way to get a small data lake working.
This is meant to be a fully functional starting point that can be expanded and customized to fit your needs.
Everything here is provided as-is, so your mileage may vary.
Please report any bugs or issues and we will try to get to them.

## Advanced topics

### Adding external data sources via Trino

External databases can be added to Walden by [connecting them to Trino](https://trino.io/docs/current/connector.html) as a separate "Catalog". The new Trino Catalog can then be [added to Superset](https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers).

This strategy allows using both Trino and Superset to interact with the external data. However, some data types (such as GIS geometry columns) may not work well with Trino. In those cases you can instead connect Superset to the external database directly as described in the next section below.

1. Uncomment and edit the `catalog_custom` setting in your `values.yaml`, then apply the changes with `deploy.sh`. This block should have the content of a `.properties` file for [the Trino connector you want](https://trino.io/docs/current/connector.html). The resulting "Catalog" name will be `custom`.
2. After running `deploy.sh`, restart the `trino-*` pods manually for the change to take effect.
    ```
    $ kubectl delete pod -n walden trino-coordinator-xxxx-yyyy trino-worker-xxxx-yyyy
    ```
3. Verify that the external data source is accessible by logging in to the `devserver` pod as described above and checking for a data source named `custom`.
    ```
    $ kubectl exec -it -n walden deployment/devserver -- /bin/bash
    # trino-cli --server trino --catalog custom
    trino> SHOW SCHEMAS;
    trino> DESCRIBE <schemaname>.<tablename>;
    ```

Now we should be able to add the new Trino catalog to Superset:

1. Open the Superset UI and log in as described above.
    ```
    $ kubectl get secret -n walden superset-admin -o 'jsonpath={.data.pass}' | base64 -d && echo
    lONGpASSWoRD64HERE
    $ kubectl port-forward -n walden deployment/superset 8088
    ```
2. Go to `Data` > `Databases` via the top menu and click the `+ Database` on the upper right to add a new Database.
3. Select the `Trino` database type from the pull down menu.
4. Set the `SQLAlchemy URI` to `trino://trino/custom`.
5. (OPTIONAL) Switch to the `Advanced` tab and enable the following:
    - SQL Lab:
        - `Expose database in SQL Lab`, followed by...
        - `Allow Multi Schema Metadata Fetch` (optional: don't enable if the DB is very large)
        - `Enable query cost estimation`
        - `Allow this database to be explored`
    - Performance:
        - `Asynchronous query execution`
6. Click `Connect` to create the new Database entry.

The new Database entry can be reconfigured again later if needed.

Now you can switch to `SQL Lab` > `SQL Editor` and preview the new Database, confirming that it looks as expected.

Check the [Trino](https://trino.io/docs/current/connector.html) and [Superset](https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers) docs for any additional information on configuring particular database types.

![Screenshot of Superset UI showing external PostGIS data via Trino](superset-external.png)

### Adding external data sources via Superset

Instead of connecting an external database via Trino and then adding the Trino schema to Superset, the external database may instead be connected to Superset directly.

This means the data will only be accessible via the Superset UI, and will not be accessible via Trino. But this may be preferable in cases like [Geometry columns](https://github.com/trinodb/trino/issues/5580) where the data may be hidden due to not being supported by Trino. Connecting these sources directly to Superset avoids this problem.

Follow the above steps for logging into the Superset UI and adding a new Database entry, except this time you should pick the type of database that you are adding, instead of Trino. The steps are otherwise similar. If your datatype isn't listed, you may need to build a custom `walden-superset` Docker image that installs the required python module(s).

Check the [Superset docs](https://superset.apache.org/docs/connecting-to-databases/installing-database-drivers) for any additional information on configuring particular database types.

### Building images using Kaniko

Cheat sheet for building images from within an existing cluster.
This can also be done locally via the Docker CLI or similar.
```
kubectl create secret -n walden docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=[your-docker-username] --docker-password=[your-docker-password]
kubectl apply -f kube-build/templates/kaniko-devserver.yaml
```

After building/pushing new release images, update the tags in `values-default.yaml`.

### Deploying with custom images

Walden can be deployed with custom images from your registry/organization.

1. Copy `values-default.yaml`, then edit the settings under the `image` section:
    - A custom registry/organization can be assigned using the `image.docker_org` setting
    - Custom tags for individual images can be assigned using `image.*_tag` settings
2. Build and push images: Run `docker/*/build.sh` and `docker/*/push.sh`
3. Deploy using custom images: Run `kube/deploy.sh values-mycopy.yaml`

### Deploying more MinIO nodes

MinIO must be deployed with at least four nodes, which is the default number used by Walden.
If you'd like to deploy more MinIO nodes, edit the `minio.replicas` setting in the `values.yaml` that you pass to `deploy.sh`.

### Deploying MinIO on alternate architectures

The MinIO images are multi-arch and so can be configured to run on nodes with non-`amd64` architectures.
In our case, we have a mixed-architecture cluster where several `arm64` Raspberry Pis provide local storage, making them a convenient place for running the MinIO pods.
To deploy with MinIO nodes on a different architecture, edit the `minio.arch` setting in the `values.yaml` that you pass to `deploy.sh`.
Note that we do not support custom architectures for the `walden-*` images themselves, as the underlying software doesn't deal with it well.
