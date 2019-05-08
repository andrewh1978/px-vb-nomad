data_dir = "/etc/nomad.d"
bind_addr= "192.168.99.99"

server {
  enabled          = true
  bootstrap_expect = 1
}

consul {
  address = "192.168.99.99:8500"
}
