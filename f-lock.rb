require 'bundler/setup'
require 'ruby-debug'
require 'rest-client'
require 'route53'
require 'scrolls'
require 'pg'

Scrolls::Log.start

$running = true

module Monitor
  extend self
  def run(z_name, c_name, endpoint)
    while($running)
      if HTTP.down?(endpoint["uri"])
        Log.puts(fn: __method__, at: "endpoint-down")
        DB.lock_zone(z_name) do
          if !DNS.empty?(z_name)
            DNS.delete(z_name, endpoint["name"])
          else
            Log.puts(fn: __method__, at: "cant-kill", msg: "last-one-standing")
          end
        end
      else
        Log.puts(fn: __method__, at: "endpoint-up")
        if !DNS.include?(z_name, endpoint["name"])
          DNS.create(z_name, c_name, endpoint["name"])
        end
      end
    end
  end
end

module DNS
  extend self

  def empty?(z_name)
    Log.puts(ns: "dns", fn: __method__, z_name: z_name)
    endpoints(z_name).empty?
  end

  def include?(z_name, endpoint)
    Log.puts(ns: "dns", fn: __method__, z_name: z_name, endpoint: endpoint)
    endpoints(z_name).any? {|e| e.values.include?(endpoint)}
  end

  def create(z_name, c_name, endpoint)
    n = [c_name, ".", z_name].join
    Log.puts(ns: "dns", fn: __method__, name: n, ident: ENV["CLOUD"]) do
      Route53::DNSRecord.
        new(n,"CNAME","0", [endpoint], zone(z_name), nil, 1, ENV["CLOUD"]).
        create
    end
  end

  def delete(z_name, endpoint)
    Log.puts(ns: "dns", fn: __method__, z_name: z_name, endpoint: endpoint) do
      endpoints(z_name).select do |e|
        e.values.include?(endpoint)
      end.map do |r|
        r.delete
      end
    end
  end

  def endpoints(z_name)
    Log.puts(ns: "dns", fn: __method__, z_name: z_name) do
      zone(z_name).get_records.select {|r| r.type == "CNAME"}
    end
  end

  def zone(z_name)
    @zone ||= conn.get_zones.find {|z| z.name == z_name}.tap do |z|
      raise "Unable to find zone=#{z_name}" unless z
    end
  end

  def conn
    @conn ||= Route53::Connection.
      new(ENV["AWS_ACCESS"], ENV["AWS_SECRET"], ENV["AWS_API_V"])
  end

end

module DB
  extend self
  SPACES = {zone: 1, endpoint: 2}

  def lock_endpoint
    all_endpoints.find {|e| lock(:endpoint, e["id"].to_i)}
  end

  def all_endpoints
    conn.exec("select * from endpoints").to_a
  end

  def endpoint_id(euri)
    r = conn.exec("select id from endpoints where uri = $1", [euri])
    r[0] && r[0]["id"].to_i
  end

  def lock_zone(z_name)
    begin
      zid = zone_id(z_name)
      until lock(:zone, zid)
        sleep(0.25)
      end
      yield if block_given?
    ensure
      unlock(:zone, zid)
    end
  end

  def zone_id(z_name)
    r = conn.exec("select id from zones where name = $1", [z_name])
    r[0] && r[0]["id"].to_i
  end

  def lock(space, pos)
    spid = SPACES[space]
    Log.puts(ns: "db", fn: __method__, space: space, spid: spid, pos: pos) do
      r = conn.exec("select pg_try_advisory_lock($1, $2)", [spid, pos])
      r[0]["pg_try_advisory_lock"] == "t"
    end
  end

  def unlock(space, pos)
    spid = SPACES[space]
    Log.puts(ns: "db", fn: __method__, space: space, spid: spid, pos: pos) do
      conn.exec("select pg_advisory_unlock($1, $2)", [spid, pos])
    end
  end

  def conn
    @con ||= PG::Connection.open(host: "localhost", dbname: 'blk_rvr')
  end
end

module HTTP
  extend self
  def down?(uri)
    Log.puts(ns: "http", fn: __method__, uri: uri) do
      begin
        Timeout::timeout(2) {RestClient.get(uri)}
        false
      rescue
        true
      end
    end
  end
end

module Log
  def self.puts(data)
    if block_given?
      Scrolls.log({:app => "f-lock"}.merge(data)) do
        yield
      end
    else
      Scrolls.log({:app => "f-lock"}.merge(data))
    end
  end
end
