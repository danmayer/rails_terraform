# Ruby on Rails deployment using Terraform, Docker, AWS Codepipeline

Dan notes:

```
# run
terraform apply --var-file=production.tfvars

> ...
> alb_dns_name = "production-alb-rails-terraform-1182706652.us-east-1.elb.amazonaws.com"
> cloudfront_distribution_domain_name = "d3oohdglm7snik.cloudfront.net"
```

updated `gitignore` to ensure secrets stay out of git

### TODOs

* load balancer SSL termination (cloudfront https only and redirect http)
* cleanup terraform deprecation warnings
* some code comment todos
* move rails app to diff repo
* make rails app repo configurable via env vars
* rails assets pushed to an S3 used via cloudfront for asset host, ensure Br compression

### What you get

* Rails app via cloudfront (NOTE: not via https): http://d3oohdglm7snik.cloudfront.net/
* Rails app via alb: https://production-alb-rails-terraform-1182706652.us-east-1.elb.amazonaws.com/
* public s3 bucket:
	* via s3 url: https://s3.amazonaws.com/s3-website-explorer-pub.test.com/assets/batman.html
	* via website url (NOTE: not via https): http://s3-website-explorer-pub.test.com.s3.amazonaws.com/assets/batman.html
	* via cloudfront (NOTE: not via https): http://d3oohdglm7snik.cloudfront.net/assets/batman.html
* private s3 bucket:
	* via s3 (private bucket but public read on the file): https://s3.amazonaws.com/s3-website-explorer-private.test.com/static/batman.html
	* via cloudfront: https://d3oohdglm7snik.cloudfront.net/static/batman.html   

### Secrets

The original project had all the files with secrets checked in... These are no longer in git and are gitignored. To enable the project to run please copy over the sample files and then edit to add various secrets.

* `cp modules/code_pipeline/main.tf.sample modules/code_pipeline/main.tf`
* `cp staging.tfvars.sample staging.tfvars`
* `cp production.tfvars.sample production.tfvars`

### Resources

  - Terraform https://www.terraform.io
  - Docker https://www.docker.com/
  - AWS Codepipeline https://aws.amazon.com/codepipeline/

### System Installation

#### Install Terraform

Install terraform using the this link [https://learn.hashicorp.com/terraform/getting-started/install.html](https://learn.hashicorp.com/terraform/getting-started/install.html)

#### You don't need local installation of docker as docker build will be run on AWS codepipeline server using buildspec.

### Github access Token

Generate a new personal github token following the steps from [this link](https://help.github.com/en/github/authenticating-to-github/creating-a-personal-access-token-for-the-command-line#creating-a-token)

Paste the token genrated in modules/copepipeline/main.tf at the following line
Also add owner for the repository you want to deploy along with repository namd and branch.
AWS code build created using terraform will read the repository owner, name, brnach from the following to run AWS code build using this source.

```
configuration = {
        Owner      = "owner_of_repo"
        Repo       = "repo_name"
        Branch     = "branch_of_repo"
        OAuthToken = "***********token*********"
      }

```

### Deploying application to AWS

In deploy.tf set access_key and secret_key for AWS account.

```
provider "aws" {
  region = var.region
  access_key = "**********************"
  secret_key = "**********************"
}
```

### Switch environment to deploy to aws

In application root folder create `.tfvars` file for staging, production, testing environment. Define all variables in `variables.tf` file and specify value for each variable in `.tfvars` file for each environment.

For example, in `variables.tf` file define variables as follows

```
variable "region" {
  description = "Region that the instances will be created"
}

/*====
environment specific variables
======*/

variable "database_name" {
  description = "The database name for Production"
}

variable "database_username" {
  description = "The username for the Production database"
}

variable "database_password" {
  description = "The user password for the Production database"
}

variable "secret_key_base" {
  description = "The Rails secret key for production"
}

variable "domain" {
  default = "The domain of your application"
}

variable "rabbit_name" {
	description = "A random environment"
}

variable "environment" {
	description = "Environment for the application"
}

variable "availability_zones" {
	type = list(string)
}
```

And in `production.tfvars` or `staging.tfvars` the value for each variable can be set.
For example in `production.tfvars`

```
region                        = "us-east-1"
domain                        = "railsterraform.com"

/* rds */
database_name      = "railsterraform_production"
database_username  = "railsterraform"
database_password  = "myawesomepasswordproduction"

/* secret key */
secret_key_base    = "8d412aee3ceaa494fe1c276f5f7e524b9e33f649c03690e689e5b36a0cf4ce2a6f50024bc31f276c22b668e619d61a42b79f5e595759f377a8fa373e2907f41e"

rabbit_name = "Yo Yo Singh"
environment = "production"

availability_zones = ["us-east-1a", "us-east-1b"]

```

After this setup run the following command in project root
`$ terraform init`

After successfully installing the terraform plugins run the plan command. When running the plan command pass `--var-file` argument to command with value of the `.tfvars` file you want to run for.
For example to deploy the application to `staging` environment run the following command

`$ terraform plan --var-file=staging.tfvars`

After successfully creating the plan run the following command

`$ terraform apply --var-file=staging.tfvars`

This will start creating your AWS infrastructure for the application and will success with providing url for the application loadbalancer using the following command

`$ terraform output alb_dns_name`
