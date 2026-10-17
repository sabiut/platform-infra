environment = "prod"
region      = "eu-west-2"
# LAB PROFILE (prod: db.t4g.medium, Multi-AZ, 50 GB, deletion protection, final snapshot,
# 7-day secret recovery window)
db_instance_class           = "db.t4g.micro"
db_multi_az                 = false
db_allocated_storage        = 20
db_deletion_protection      = false
skip_final_snapshot         = true
secret_recovery_window_days = 0
app_namespace               = "webapp-prod"
