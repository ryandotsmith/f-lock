require './blk_rvr'

z_name = "shushud-partitioned.net."
c_name = "service"

=begin
puts endpoint = DB.lock_endpoint
puts DNS.include?(z_name, endpoint["name"])
puts DNS.create(z_name, c_name, endpoint["name"])
puts DNS.delete(z_name, endpoint["name"])
=end

Monitor.run("shushud-partitioned.net.", "service", DB.lock_endpoint)
