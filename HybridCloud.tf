// Create a GCP Provider
provider "google" {
  credentials = "${file("/Users/kaizentek/.ssh/example.json")}"
  project     = "terraform-208319"
  region      = "us-central1"
}

//  Create an AWS Provider
provider "aws" {
    shared_credentials_file = "/Users/kaizentek/.aws/credentials"
    region = "us-east-1"
}

resource "google_storage_bucket" "terraform-storage-122129" {
  name     = "terraform-storage-122129"
}

// Create an EC2 instance, bootstrap it with an application, SG, and subnetting
resource "aws_instance" "terraform-aws-a" {
     count = 1
     ami = "${var.amazon-linux}" 
     instance_type = "t2.micro"
     key_name = "${var.ssh_key}"
     subnet_id = "${var.subnet-us-east-1a}"
     security_groups = ["${var.terraform-sg}"]
     tags {
         Name = "terraform-aws-1a"
         Environment = "${var.production}"
     }

     provisioner "local-exec" {
        command = "echo ${self.private_ip} > file.txt"
      }

     provisioner "remote-exec" {

         connection {
             user = "ec2-user"
             type = "ssh"
             private_key = "${file("/Users/kaizentek/.ssh/example.pem")}"
         }


         inline = [
            "sudo yum update -y",
             "sudo yum install -y golang",
             "sudo yum install -y git",
             "export GOROOT=/usr/lib/golang",
             "export GOPATH=$HOME/projects",
             "export PATH=$PATH:$GOROOT/bin",
             "sudo yum install -y git",
             "git clone https://github.com/JohnAntonusMaximus/golang-webserver.git",
             "cd golang-webserver",
             "go build .",
             "chmod +x golang-webserver",
             "nohup ./golang-webserver ${"https://storage.googleapis.com/${google_storage_bucket.terraform-storage-122129.name}/${google_storage_bucket_object.mona-lisa.name}"} ${"https://storage.googleapis.com/${google_storage_bucket.terraform-storage-122129.name}/${google_storage_bucket_object.css.name}"} &",
             "sleep 1"
    ]
     }
 }

 // Create an EC2 instance, bootstrap it with an application, SG, and subnetting
resource "aws_instance" "terraform-aws-b" {
     count = 1
     ami = "${var.amazon-linux}"
     instance_type = "t2.micro"
     key_name = "${var.ssh_key}"
     subnet_id = "${var.subnet-us-east-1b}"
     security_groups = ["${var.terraform-sg}"]
     tags {
         Name = "terraform-aws-1b"
         Environment = "${var.production}"
     }

     provisioner "remote-exec" {

         connection {
             user = "ec2-user"
             type = "ssh"
             private_key = "${file("/Users/kaizentek/.ssh/example.pem")}"
         }

         inline = [
            "sudo yum update -y",
             "sudo yum install -y golang",
             "sudo yum install -y git",
             "export GOROOT=/usr/lib/golang",
             "export GOPATH=$HOME/projects",
             "export PATH=$PATH:$GOROOT/bin",
             "sudo yum install -y git",
             "git clone https://github.com/JohnAntonusMaximus/golang-webserver.git",
             "cd golang-webserver",
             "go build .",
             "chmod +x golang-webserver",
             "nohup ./golang-webserver ${"https://storage.googleapis.com/${google_storage_bucket.terraform-storage-122129.name}/${google_storage_bucket_object.mona-lisa.name}"} ${"https://storage.googleapis.com/${google_storage_bucket.terraform-storage-122129.name}/${google_storage_bucket_object.css.name}"} &",
             "sleep 1"
    ]
     }
 }

// Create an application loadbalancer (HTTP/HTTPS) with port forwarding (80:8097)
resource "aws_alb" "terraform-alb" {
  name = "terraform-elb"
  internal = false
  load_balancer_type = "application"
  security_groups = ["${var.terraform-sg}"]
  subnets = ["${var.subnet-us-east-1a}", "${var.subnet-us-east-1b}", "${var.subnet-us-east-1c}"]
  enable_cross_zone_load_balancing = true
  enable_deletion_protection = false

  tags {
    Environment = "${var.production}"
    Name = "terraform-elb"
  }
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = "${aws_alb.terraform-alb.arn}"
  port              = "${var.loadbalancer_HTTP_listen_port}"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.terraform-target-group.arn}"
    type             = "forward"
  }
}

resource "aws_alb_target_group" "terraform-target-group" {
  name = "terraform-target-group"
  port = "${var.application_target_port}"
  protocol = "HTTP"
  vpc_id = "${var.terraform-VPC}"
  target_type = "instance"
  tags {
    name = "terraform-target-group"
  }
  health_check {
    path = "/generic"
    matcher = "200-299"
  }
}

resource "aws_alb_target_group_attachment" "terraform-tg-instance-attachment-group-a" {
  target_group_arn = "${aws_alb_target_group.terraform-target-group.arn}"
  target_id = "${aws_instance.terraform-aws-a.id}"
  port = "${var.application_target_port}"
}

resource "aws_alb_target_group_attachment" "terraform-tg-instance-attachment-group-b" {
  target_group_arn = "${aws_alb_target_group.terraform-target-group.arn}"
  target_id = "${aws_instance.terraform-aws-b.id}"
  port = "${var.application_target_port}"
}


resource "google_storage_bucket_acl" "bucket-acl" {
  bucket = "${google_storage_bucket.terraform-storage-122129.name}"
  predefined_acl = "publicRead"
}

resource "google_storage_bucket_object" "mona-lisa" {
  name   = "mona-lisa.jpg"
  source = "/Users/kaizentek/Desktop/HybridCloud/scripts/images/mona-lisa.jpg"
  bucket = "${google_storage_bucket.terraform-storage-122129.name}"
}

resource "google_storage_bucket_object" "css" {
  name   = "stylescopy.css"
  content_type = "text/css"
  source = "/Users/kaizentek/Desktop/HybridCloud/scripts/assets/css/stylescopy.css"
  bucket = "${google_storage_bucket.terraform-storage-122129.name}"
}

resource "google_storage_object_acl" "img-acl" {
  bucket = "${google_storage_bucket.terraform-storage-122129.name}"
  object = "${google_storage_bucket_object.mona-lisa.name}"

  role_entity = ["${var.publicReadObject}"]
}

resource "google_storage_object_acl" "css-acl" {
  bucket = "${google_storage_bucket.terraform-storage-122129.name}"
  object = "${google_storage_bucket_object.css.name}"

  role_entity = ["${var.publicReadObject}"]
}