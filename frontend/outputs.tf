output "s3_bucket_name" {
  description = "The name of the s3 bucket"
  value       = aws_s3_bucket.vpro-s3.id
}
