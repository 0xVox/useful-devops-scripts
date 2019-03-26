provider "google" {
  credentials = "${file("${var.key-location}")}"
  project     = "${var.project}"
  region      = "us-central1"
  zone        = "us-central1-a"
}