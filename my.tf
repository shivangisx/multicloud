provider "aws" {
  region     = "ap-south-1"
  profile    = "shivprofile"
  
}



  resource "aws_instance" "localVM" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  security_groups = [ "sg1" ]
  key_name      = "mykey11"
  tags = {
    Name = "localVM"
  }


provisioner "remote-exec" {
          inline = [
            "sudo yum install httpd  php git -y",
            "sudo systemctl restart httpd",
            "sudo systemctl enable httpd",
            
          
         ]
        }
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/USER/Desktop/aws/mykey11.pem")
    host     = aws_instance.localVM.public_ip
  }
}



output "myout2" {
	value = aws_instance.localVM.public_ip
}



resource "null_resource" "nulllocal2" {
provisioner "local-exec" {
    command = "echo ${aws_instance.localVM.public_ip} > publicip.txt "
	}
}


resource "aws_ebs_volume" "ebs1" {
  availability_zone = aws_instance.localVM.availability_zone
  size              = 1

  tags = {
    Name = "ebs1"
  }
}
//volume attach 
resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.ebs1.id
  instance_id = aws_instance.localVM.id
  force_detach = true
}

resource "null_resource" "nullremote" {

depends_on = [
	aws_volume_attachment.ebs_attach,
]

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/USER/Desktop/aws/mykey11.pem")
    host     = aws_instance.localVM.public_ip
  }

provisioner "remote-exec" {
        inline = [
          "sudo mkfs.ext4  /dev/xvdh",
          "sudo mount  /dev/xvdh  /var/www/html",
          "sudo rm -rf /var/www/html/*",
          "sudo git clone https://github.com/shivangisx/multicloud.git /var/www/html/"
        ]
      }
}



//copy image fron git to local

//resource "null_resource" "git_copy"  {
//      provisioner "local-exec" {
//        command = "git clone https://github.com/shivangisx/multicloud.git C:/Users/USER/Desktop/aws/g/" 
//    }
//    }


//s3


resource "aws_s3_bucket" "mys3bucket4092" {
        
        bucket = "mys3bucket4092"
        acl    = "public-read"
        region = "ap-south-1"

        tags = {
          Name        = "mys3bucket4092"
	  Environment = "Deploy"
        }
      }
resource "aws_s3_bucket_public_access_block" "mys3bucket4092_public"{

	bucket = "mys3bucket4092"
	block_public_acls = false
	block_public_policy = false

}




resource "aws_s3_bucket_object" "mys3bucketobj" {
	
          bucket = "mys3bucket4092"
          key    = "myimage.jpg"
          source = "C:/Users/USER/Pictures/image.jpg"
          acl    = "public-read"
        }



//cloud front

locals {
          s3_origin_id = "myoriginS3id"
        }

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
comment = "Some comment access identity"
}
resource "aws_cloudfront_distribution" "my_cloudfront" {
         origin {
               domain_name = "mys3bucket4092.s3.ap-south-1.amazonaws.com"
               origin_id   = "${local.s3_origin_id}"

 	s3_origin_config {
			  origin_access_identity = "${aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path}"
			}      
	
       
            }
               enabled = true

       default_cache_behavior {

               allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
               cached_methods   = ["GET", "HEAD"]
               target_origin_id = "${local.s3_origin_id}"

       forwarded_values {

             query_string = false

       cookies {
                forward = "none"
               }
          }

                viewer_protocol_policy = "allow-all"
                min_ttl                = 0
                default_ttl            = 3600
                max_ttl                = 86400

      }
      

      
  restrictions {
     geo_restriction {
          restriction_type = "none"
          }
           }
     viewer_certificate {
             cloudfront_default_certificate = true
             }
      }


output "domain-name" {
	value = aws_cloudfront_distribution.my_cloudfront.domain_name
}

data "aws_iam_policy_document" "s3_policy" {
	statement {
	actions = ["s3:GetObject"]
	resources = ["${aws_s3_bucket.mys3bucket4092.arn}/*"]
	principals {
	type = "AWS"
	identifiers = ["${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"]
		}
	}
}
resource "aws_s3_bucket_policy" "example" {

	bucket = aws_s3_bucket.mys3bucket4092.id
	policy = data.aws_iam_policy_document.s3_policy.json
}


resource "null_resource" "chrome"  {
      provisioner "local-exec" {
        command = "start chrome " 
        }
    }