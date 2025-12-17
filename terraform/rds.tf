# RDS Database for Backend
# Uncomment and configure when ready to use database

# resource "aws_db_subnet_group" "main" {
#   name       = "${var.project_name}-db-subnet-group"
#   subnet_ids = module.vpc.private_subnets
# 
#   tags = merge(var.tags, {
#     Name = "${var.project_name}-db-subnet-group"
#   })
# }
# 
# resource "aws_security_group" "rds" {
#   name        = "${var.project_name}-rds-sg"
#   description = "Security group for RDS database"
#   vpc_id      = module.vpc.vpc_id
# 
#   ingress {
#     from_port       = 5432
#     to_port         = 5432
#     protocol        = "tcp"
#     security_groups = [module.eks.node_security_group_id]
#   }
# 
#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# 
#   tags = merge(var.tags, {
#     Name = "${var.project_name}-rds-sg"
#   })
# }
# 
# resource "aws_db_instance" "main" {
#   identifier             = "${var.project_name}-db"
#   engine                 = "postgres"
#   engine_version         = "15.4"
#   instance_class         = "db.t3.micro"
#   allocated_storage      = 20
#   storage_type           = "gp3"
#   storage_encrypted      = true
#   db_name                = "itemsdb"
#   username               = "admin"
#   password               = var.db_password # Use AWS Secrets Manager in production
#   vpc_security_group_ids = [aws_security_group.rds.id]
#   db_subnet_group_name   = aws_db_subnet_group.main.name
#   backup_retention_period = 7
#   backup_window          = "03:00-04:00"
#   maintenance_window     = "mon:04:00-mon:05:00"
#   skip_final_snapshot    = true
#   publicly_accessible    = false
# 
#   tags = merge(var.tags, {
#     Name = "${var.project_name}-db"
#   })
# }
# 
# output "rds_endpoint" {
#   value       = aws_db_instance.main.endpoint
#   description = "RDS instance endpoint"
# }

