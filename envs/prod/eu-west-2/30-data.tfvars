environment = "prod"
region      = "eu-west-2"

# London is a warm standby: a cross-region read replica of Sydney's database. Reads work,
# writes fail until the replica is promoted (docs/database-failover.md). Sydney's 30-data
# must be applied first; apply.yml waits for it.
db_role                = "replica"
db_primary_region      = "ap-southeast-2"
db_multi_az            = true
db_deletion_protection = true # destroy.yml turns it off just before destroying

# LAB PROFILE (prod: db.t4g.medium, 50 GB, final snapshot, 7-day secret recovery window)
db_instance_class           = "db.t4g.micro"
db_allocated_storage        = 20
skip_final_snapshot         = true
secret_recovery_window_days = 0
app_namespace               = "webapp-prod"
