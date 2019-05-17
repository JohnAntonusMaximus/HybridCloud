output "gcp-object-url" {
    value = "https://storage.googleapis.com/${google_storage_bucket.terraform-storage-122129.name}/${google_storage_bucket_object.mona-lisa.name}"
}

output "assets-url" {
    value = "https://storage.googleapis.com/${google_storage_bucket.terraform-storage-122129.name}/${google_storage_bucket_object.css.name}"
}

output "aws-elb-dns" {
    value = "http://${aws_alb.terraform-alb.dns_name}:8097"
}