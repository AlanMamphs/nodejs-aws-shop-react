

resource "aws_s3_bucket" "react_nodejs_terraform" {
  bucket = "react.nodejs.terraform"

  tags = {
    Name        = "React Nodejs Terraform"
    Environment = "Dev"
  }
}


resource "aws_s3_bucket_versioning" "react_nodejs_terraform" {
  bucket = aws_s3_bucket.react_nodejs_terraform.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_public_access_block" "block_public_access" {
  bucket = aws_s3_bucket.react_nodejs_terraform.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

variable "mime_types" {
  default = {
    htm  = "text/html"
    html = "text/html"
    css  = "text/css"
    ttf  = "font/ttf"
    js   = "application/javascript"
    map  = "application/javascript"
    json = "application/json"
  }
}

resource "aws_s3_object" "dist" {
  for_each     = fileset("../dist", "**/*.*")
  bucket       = aws_s3_bucket.react_nodejs_terraform.id
  key          = each.value
  source       = "../dist/${each.value}"
  content_type = lookup(var.mime_types, split(".", each.value)[length(split(".", each.value)) - 1])
  # etag makes the file update when it changes; see https://stackoverflow.com/questions/56107258/terraform-upload-file-to-s3-on-every-apply
  etag = filemd5("../dist/${each.value}")

  provisioner "local-exec" {
    command     = "DISTRIBUTION_ID=${aws_cloudfront_distribution.cf_distribution.id} ./scripts/invalidate_cf.sh"
    interpreter = ["/bin/bash", "-c"]
  }
}

resource "aws_s3_bucket_policy" "allow_access_from_cdn" {
  bucket = aws_s3_bucket.react_nodejs_terraform.id
  policy = data.aws_iam_policy_document.allow_access_from_cdn.json
}

data "aws_iam_policy_document" "allow_access_from_cdn" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.oai.iam_arn]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      aws_s3_bucket.react_nodejs_terraform.arn,
      "${aws_s3_bucket.react_nodejs_terraform.arn}/*",
    ]
  }
}
