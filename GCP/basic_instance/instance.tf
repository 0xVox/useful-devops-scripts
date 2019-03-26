resource "google_compute_instance" "vm_instance" {
  name         = "${var.project}-test"
  machine_type = "f1-micro"
  description  = "Basic GCP ${self.machine_type} instance"
  service_account {
    scopes = ["cloud-platform"]
  }

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-lts"
    }
  }

  network_interface {
    # A default network is created for all GCP projects
    network       = "${google_compute_network.vpc_network.self_link}"
    access_config = {
    }
  }
  
}

output "instance_id" {
  value = "${google_compute_instance.vm_instance.self_link}"
}

