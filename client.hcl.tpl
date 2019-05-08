datacenter = "dc1"
data_dir   = "/etc/nomad.d"
bind_addr  = "192.168.99.10NODE"

client {
  enabled = true
  servers = ["192.168.99.99:4647"]
}

consul {
  address = "192.168.99.99:8500"
}
