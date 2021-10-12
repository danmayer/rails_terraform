output "alb_dns_name" {
  value = module.ecs.alb_dns_name
}

output "cloudfront_distribution_domain_name" {
  description = "The domain name corresponding to the distribution."
  value       = module.cdn.cloudfront_distribution_domain_name
}