# Database failover: promote London

Sydney (`ap-southeast-2`) holds the writable PostgreSQL database. London (`eu-west-2`) holds a
cross-region read replica of it, kept up to date by RDS (usually seconds behind). Both are
Multi-AZ, so losing one availability zone is handled inside the region with no action here.

This runbook is for losing the Sydney **region**, or deciding to move writes to London.

## What runs where in normal operation

| | Sydney | London |
|---|---|---|
| RDS | primary, read/write | read replica, read-only |
| `prod/webapp/database` (username, password) | the secret | a copy, replicated by Secrets Manager |
| `prod/webapp/database-endpoint` (host, port) | Sydney's database | London's replica |
| Django migrations (`migrate.enabled`) | run on every release | off: the schema arrives by replication |
| Web app | serves everything | serves reads; writes return errors |

## Failover

1. **Promote the replica.** It becomes a standalone, writable database. RDS stops replicating
   from Sydney, permanently.

       aws rds promote-read-replica --region eu-west-2 \
         --db-instance-identifier prod-eu-west-2-webapp
       aws rds wait db-instance-available --region eu-west-2 \
         --db-instance-identifier prod-eu-west-2-webapp

2. **Make London's credentials secret independent.** Skip this if Sydney is only being
   drained on purpose and stays reachable. If the Sydney region is down, the replicated copy
   keeps working, but promote it so it can be changed on its own:

       aws secretsmanager stop-replication-to-replica --region eu-west-2 \
         --secret-id prod/webapp/database

3. **Turn migrations back on in London.** In `gitops`, remove the `migrate:` block from
   `envs/prod/eu-west-2/values/backend.yaml` and merge. Argo CD runs the migrate Job on the
   next sync, which is a no-op unless the release has new migrations.

4. **Send users to London.** Without a domain there's no DNS to switch: give out London's ALB
   address. With a domain, point the Route 53 record (or its failover routing) at London's ALB.

5. **Check** writes in London: create a note through the UI or `POST /api/notes/`.

## Afterwards

Terraform still describes London as a replica (`db_role = "replica"` in
`envs/prod/eu-west-2/30-data.tfvars`). Don't apply `30-data` in London until that's sorted.
The way back is to rebuild Sydney as a replica of London, then fail back in a planned window
with the same steps in the other direction.

## Limits

- Replication is asynchronous: writes made in Sydney in the last few seconds before it was
  lost may be missing in London.
- Each region keeps its own media bucket and Django `SECRET_KEY`. After a failover, files
  uploaded in Sydney aren't in London, and users sign in again.
- A planned failover is the same procedure: stop writes in Sydney first (scale the backend to
  zero), wait for `ReplicaLag` to reach 0 in CloudWatch, then promote.
