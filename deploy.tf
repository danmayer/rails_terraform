/*====
Variables used across all modules
======*/
locals {
  availability_zones = var.availability_zones
}

provider "aws" {
  region = var.region
  access_key = var.aws_key
  secret_key = var.aws_secret_key
}

resource "aws_key_pair" "key" {
  key_name   = "production_key"
  public_key = file("terraform_rsa.pub")
}

resource "aws_s3_bucket" "private_bucket" {
  /*==== NOTE: you need to make a unique bucket name, perhaps move to variable  ====*/
  bucket = "s3-website-explorer-private.test.com"
  acl    = "private"

  tags = {
    Name = "A private bucket"
  }
}

resource "aws_s3_bucket" "public_bucket" {
  /*==== NOTE: you need to make a unique bucket name, perhaps move to variable  ====*/
  bucket = "s3-website-explorer-pub.test.com"
  acl    = "public-read"
  /*====
  policy = file("policy.json")
  ====*/  

  website {
    index_document = "index.html"
    error_document = "error.html"

    routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "docs/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": "documents/"
    }
}]
EOF
  }
}

module "cdn" {
  source = "terraform-aws-modules/cloudfront/aws"

/*====
  aliases = ["cdn.example.com"]
======*/  

  comment             = "My exploring CloudFront"
  enabled             = true
  is_ipv6_enabled     = true
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  create_origin_access_identity = true
  origin_access_identities = {
    s3_bucket_one = "My awesome CloudFront can access"
  }

/*====
  logging_config = {
    bucket = "explore-logs-my-cdn.s3.amazonaws.com"
  }
======*/  

  origin = {
    something = {
      /*====
      move to using the output variable of the ELB
      ======*/  
      domain_name = "production-alb-rails-terraform-1182706652.us-east-1.elb.amazonaws.com"
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
    }

    s3_one = {
      domain_name = aws_s3_bucket.private_bucket.bucket_regional_domain_name
      s3_origin_config = {
        origin_access_identity = "s3_bucket_one"
      }
    }

    s3_two = {
      domain_name = aws_s3_bucket.public_bucket.bucket_regional_domain_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "match-viewer"
        origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "something"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    query_string    = true
  }

  ordered_cache_behavior = [
    {
      path_pattern           = "/static/*"
      target_origin_id       = "s3_one"
      viewer_protocol_policy = "redirect-to-https"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true
    },
    {
      path_pattern           = "/assets/*"
      target_origin_id       = "s3_two"
      viewer_protocol_policy = "allow-all"

      allowed_methods = ["GET", "HEAD", "OPTIONS"]
      cached_methods  = ["GET", "HEAD"]
      compress        = true
      query_string    = true
    }
  ]

  viewer_certificate = {
    /*====
    acm_certificate_arn = "arn:aws:acm:us-east-1:135367859851:certificate/1032b155-22da-4ae0-9f69-e206f825458b"
    ssl_support_method  = "sni-only"
    ======*/  
    cloudfront_default_certificate = true
  }
}

module "networking" {
  source               = "./modules/networking"
  environment          = var.environment
  vpc_cidr             = "10.0.0.0/16"
  public_subnets_cidr  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets_cidr = ["10.0.10.0/24", "10.0.20.0/24"]
  region               = var.region
  availability_zones   = local.availability_zones
  key_name             = "production_key"
}

module "rds" {
  source            = "./modules/rds"
  environment       = var.environment
  allocated_storage = "20"
  database_name     = var.database_name
  database_username = var.database_username
  database_password = var.database_password
  subnet_ids        = module.networking.private_subnets_id
  vpc_id            = module.networking.vpc_id
  instance_class    = "db.t2.micro"
}

module "ecs" {
  source             = "./modules/ecs"
  environment        = var.environment
  vpc_id             = module.networking.vpc_id
  availability_zones = local.availability_zones
  repository_name    = "rails_terraform/production"
  subnets_ids        = module.networking.private_subnets_id
  public_subnet_ids  = module.networking.public_subnets_id
  security_groups_ids = concat([module.rds.db_access_sg_id], module.networking.security_groups_ids)
  database_endpoint = module.rds.rds_address
  database_name     = var.database_name
  database_username = var.database_username
  database_password = var.database_password
  secret_key_base   = var.secret_key_base
}

