# Upgrade 2021 S2D2 to 2024 S4D2
This example simulates a MinIO upgrade from `RELEASE.2021-01-05T05-22-38Z`
to `RELEASE.2024-06-04T19-20-08Z`. It does this by simulating multiple MinIO
servers using Docker (each container is a Docker container) and expose the
"cluster" via NGINX.

### Create the "initial" system
Setting up the initial system can be done by starting `docker compose
-f docker-compose-2021.yml up`. This will start two MinIO containers with
each two disks and expose them locally on http://localhost:9000.

Make sure a recent version of `mc` is installed (see https://min.io/docs/minio/linux/reference/minio-mc.html
for instructions on how to install). Then add an alias for the local MinIO
system using `mc alias set local http://localhost:9000 minio minio123`.

Then run `mc mb local/test1` to create a test bucket. You can then copy data
to MinIO using `mc cp -r <local-path> local/test1`. If you have a lot of data
this can take a while. If you want to test with actual data, then you can also
use `mc mirror` to copy the data to this simulation cluster.

Note that all data is stored in the following directories:

 - `s1d1`: Server 1 (disk 1)
 - `s1d2`: Server 1 (disk 2)
 - `s2d1`: Server 2 (disk 1)
 - `s2d2`: Server 2 (disk 2)

This old version doesn't support `mc admin info` yet, so we can't show the
cluster information yet.

### Upgrade the cluster to 2024
Before upgrading you can backup all the metadata using the `backup.sh` command
in this repository (tailored for this app and not for generic use). Make sure
the cluster is stopped (just hit CTRL-C in the window that runs the cluster).

Once the cluster is stopped and backed up, then you can start the new MinIO
release using `docker compose -f docker-compose-2024a.yml up`. This will start
the same servers, but with a new MinIO server. The MinIO will upgrade all
metadata in-place.

Run `mc admin info local` to see the information about the "cluster". It will
report something like this:
```
●  minio1:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 2/2 OK
   Drives: 2/2 OK
   Pool: 1

●  minio2:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 2/2 OK
   Drives: 2/2 OK
   Pool: 1

┌──────┬───────────────────────┬─────────────────────┬──────────────┐
│ Pool │ Drives Usage          │ Erasure stripe size │ Erasure sets │
│ 1st  │ 7.3% (total: 1.9 TiB) │ 4                   │ 1            │
└──────┴───────────────────────┴─────────────────────┴──────────────┘

22 GiB Used, 1 Bucket, 776 Objects
4 drives online, 0 drives offline, EC:2
```
You may have different available disk space, but erasure stripe size, EC parity
and number of pools should be the same.


It should show the same information, but only the version number should be the
new 2024 version. You can still interact with the data using `mc`

### Extend storage by adding a new pool
The `docker-compose-2024b.yml` file adds 4 new servers (with 2 disks) that use
the same version as before (all versions within a cluster should be the same)
and adds the new servers as a new pool. Run `docker compose -f
docker-compose-2024b.yml up` to start the extended cluster.

You can now interact with the cluster, but it will report two pools when you
run `mc admin info local`:
```
●  minio1:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 6/6 OK
   Drives: 2/2 OK
   Pool: 1

●  minio2:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 6/6 OK
   Drives: 2/2 OK
   Pool: 1

●  new1:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 6/6 OK
   Drives: 2/2 OK
   Pool: 2

●  new2:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 6/6 OK
   Drives: 2/2 OK
   Pool: 2

●  new3:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 6/6 OK
   Drives: 2/2 OK
   Pool: 2

●  new4:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 6/6 OK
   Drives: 2/2 OK
   Pool: 2

┌──────┬───────────────────────┬─────────────────────┬──────────────┐
│ Pool │ Drives Usage          │ Erasure stripe size │ Erasure sets │
│ 1st  │ 7.3% (total: 1.9 TiB) │ 4                   │ 1            │
│ 2nd  │ 7.3% (total: 5.6 TiB) │ 8                   │ 1            │
└──────┴───────────────────────┴─────────────────────┴──────────────┘

22 GiB Used, 1 Bucket, 776 Objects
12 drives online, 0 drives offline, EC:2
```
The system uses a default stripe size of 8 for a 4 server system (with 2 disks per server).
The parity is still limited to EC:2, because the old pool uses a stripe size of 4 and that
limits parity to EC:2.

### Decomission the old pool
The old pool can now be decomissioned, so it moves all data from the old pool to the new pool
without downtime. Detailed instructions can be found [here](https://min.io/docs/minio/linux/operations/install-deploy-manage/decommission-server-pool.html),
but you can run the following commands:

 1. Show current decommission status: `mc admin decommission status local`.
 2. Start decomissioning of the old pool: `mc admin decommission start local 'http://minio{1...2}/data{1...2}'`.
 3. Check the decommission status: `mc admin decommission status local` and wait until the
    old pool shows status `Complete`. It will be `Draining` while it's still decomissioning
    the pool.


### Run with only the new pool
Once the pool is fully drained, the pool can be removed from the cluster. This can be done
by running `docker compose -f docker-compose-2024c.yml up`. This will restart the cluster,
but without the containers that represented the old pool. All data will still be available
and you can test it by deleting the `s?d?` directories using `rm -rf s[12]d[12]`.

When you now run `mc admin info local`, then it will show the following information:
```
●  new1:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 4/4 OK
   Drives: 2/2 OK
   Pool: 1

●  new2:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 4/4 OK
   Drives: 2/2 OK
   Pool: 1

●  new3:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 4/4 OK
   Drives: 2/2 OK
   Pool: 1

●  new4:9000
   Uptime: ...
   Version: 2024-06-04T19:20:08Z
   Network: 4/4 OK
   Drives: 2/2 OK
   Pool: 1

┌──────┬───────────────────────┬─────────────────────┬──────────────┐
│ Pool │ Drives Usage          │ Erasure stripe size │ Erasure sets │
│ 1st  │ 5.6% (total: 3.7 TiB) │ 8                   │ 1            │
└──────┴───────────────────────┴─────────────────────┴──────────────┘

24 GiB Used, 1 Bucket, 791 Objects
8 drives online, 0 drives offline, EC:4
```
Most important to note that the system now shows `EC:4`, because the erasure stripe size of 8
will use a default parity of 4. Note that this setting only is valid for data that is written
since the cluster is running with **ONLY** the new pool. All data that was moved to the new
pool is still using `EC:2`, because the cluster was running at `EC:2` at that time.

You may want to switch to `EC:2` for new data by setting the `MINIO_STORAGE_CLASS_STANDARD=EC:2`
environment variable (see also https://min.io/docs/minio/linux/reference/minio-server/settings/storage-class.html).

### Alternative solution (mirror)
If you need more parity than EC:2, then you can't use migrating data using deprovisioning,
because you're limited to the lowest (common) parity of your pools. In that case it may be
better to create a new cluster and use `mc mirror` to copy all data from one cluster to
another cluster.

To avoid missing data (or missing deletes) it may be better to stop all clients that access
the cluster to ensure the data is static. Also migrating from the old to the new server may
take time (i.e. when changing DNS records), so make sure you properly plan this procedure.

