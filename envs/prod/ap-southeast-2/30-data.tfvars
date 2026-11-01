environment = "prod"
region      = "ap-southeast-2"

# Sydney holds the writable database. Secrets Manager replicates its credentials secret to
# London, where 30-data builds a cross-region read replica of this instance.
db_role                = "primary"
db_replica_regions     = ["eu-west-2"]
db_multi_az            = true
db_deletion_protection = true # destroy.yml turns it off just before destroying

# LAB PROFILE (prod: db.t4g.medium, 50 GB, final snapshot, 7-day secret recovery window)
db_instance_class           = "db.t4g.micro"
db_allocated_storage        = 20
skip_final_snapshot         = true
secret_recovery_window_days = 0
app_namespace               = "webapp-prod"
