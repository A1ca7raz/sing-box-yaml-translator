#!/usr/bin/env ruby
require 'yaml'
require 'json'
require 'open-uri'

def check_file (file)
    File.file?(file.to_s) && File.readable?(file.to_s)
end

if ARGV[0].is_a?(String)
    if check_file(ARGV[0])
        $tpl = ARGV[0]
    else
        STDERR.puts "#{ARGV[0]}: no such file or file unreadable"
        exit!
    end
else
    $tpl = "config.yml" if check_file("config.yml")
    $tpl = "config.yaml" if check_file("config.yaml")
    if $tpl.is_a?(NilClass)
        STDERR.puts "#{__FILE__}: missing file operand"
        STDOUT.puts "Usage: #{__FILE__} [filename]"
        exit!
    else
        STDOUT.puts "#{$tpl}: default file detected"
    end
end

def parse_ss (node)
    {"tag" => node["name"],
     "type" => "shadowsocks",
     "server" => node["server"],
     "server_port" => node["port"],
     "method" => node["cipher"],
     "password" => node["password"]}
end

def parse_trojan (node)
    {"tag" => node["name"],
     "type" => "trojan",
     "server" => node["server"],
     "server_port" => node["port"],
     "password" => node["password"],
     "tls" => {"enabled" => true,
               "server_name" => node["sni"]}}
end

def parse_vmess (node)
    {"tag" => node["name"],
     "type" => "vmess",
     "server" => node["server"],
     "server_port" => node["port"],
     "uuid" => node["uuid"],
     "alter_id" => node["alterId"],
     "tls" => {"enabled" => node["tls"],
               "server_name" => node["servername"]},
     "transport" => {"type" => node["network"],
                     "path" => node["ws-path"],
                     "headers" => node["ws-headers"]}}
end

def parse_node (node)
    case node["type"]
    when "ss"
        parse_ss node
    when "trojan"
        parse_trojan node
    when "vmess"
        parse_vmess node
    end
end

# Parse YAML template
tpl = YAML.safe_load_file($tpl, aliases: true)

# Fetch proxy providers
providers = tpl.fetch("outbound-providers", {})
outbounds = []
outbound_tags = []
provider_tags = providers.keys
providers.each_key do |sub|
    return unless providers[sub].key?("url")

    # Local
    if providers[sub]["type"] == "file"
        proxies = YAML.safe_load_file(providers[sub]["url"])["proxies"]
    else
        # Http
        sub_res = URI.open(providers[sub]["url"])
        sub_raw = "---\n" + sub_res.read
        proxies = YAML.load(sub_raw)["proxies"]
    end

    return unless proxies.is_a?(Array) && ! proxies.empty?
    # Parse proxies
    proxies.map! do |node|
        parse_node node
    end
    outbounds.concat(proxies)
    providers[sub]["nodes"] = proxies.map { |v| v["tag"]}
    outbound_tags.concat(providers[sub]["nodes"])
end

# Fill outbounds
if tpl.fetch("outbounds", nil).is_a?(Array)
    tpl["outbounds"].concat(outbounds)
else
    tpl["outbounds"] = outbounds
end

# Handle use&filter
tpl["outbounds"] = tpl["outbounds"].each do |node|
    uses = node.fetch("use", [])
    unless uses.empty?
        if provider_tags & uses == uses
            uses.map! {|sub| providers[sub]["nodes"]}
            uses.flatten!
            uses.reject! {|i| ! i[/#{node["filter"]}/]} if node.key?("filter")
            if node.fetch("outbounds", nil).is_a?(Array)
                node["outbounds"].concat(uses)
            else
                node["outbounds"] = uses
            end
        end
        node.delete("filter")
        node.delete("use")
    end
end

# Cleanup
SING_BOX_STRUCTURE = ["log", "dns", "ntp", "inbounds", "outbounds", "route", "experimental"]
tpl.reject! {|k, v| ! SING_BOX_STRUCTURE.include?(k)}

# Write to JSON
File.open("config.json", "w") do |file|
    file.write(JSON.pretty_generate(tpl))
end