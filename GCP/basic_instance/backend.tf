terraform{
  backend "gcs" {
    bucket  = "${var.project}-terraform"
    prefix  = "terraform/state"
    project = "${var.project}"
  }
}