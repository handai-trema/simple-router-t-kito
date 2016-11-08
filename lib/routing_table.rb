# Routing table
class RoutingTable
  include Pio

  MAX_NETMASK_LENGTH = 32
  DUMP_ALL_NETMASK_LENGTH = 0

  def initialize(route)
    @db = Array.new(MAX_NETMASK_LENGTH + 1) { Hash.new }
    route.each { |each| add(each) }
  end

  def add(options)
    netmask_length = options.fetch(:netmask_length)
    prefix = IPv4Address.new(options.fetch(:destination)).mask(netmask_length)
    if netmask_length == 0 || IPv4Address.new(options.fetch(:destination)).mask(netmask_length) == IPv4Address.new(options.fetch(:next_hop)).mask(netmask_length)
      @db[netmask_length][prefix.to_i] = IPv4Address.new(options.fetch(:next_hop))
      return "success\n"
    end
    return "Network address is different\n"
  end

  def delete(options)
    netmask_length = options.fetch(:netmask_length)
    prefix = IPv4Address.new(options.fetch(:destination)).mask(netmask_length)
    @db[netmask_length].delete(prefix.to_i)
  end

  def lookup(destination_ip_address)
    MAX_NETMASK_LENGTH.downto(0).each do |each|
      prefix = destination_ip_address.mask(each)
      entry = @db[each][prefix.to_i]
      return entry if entry
    end
    nil
  end

  def dump(netmask_length=DUMP_ALL_NETMASK_LENGTH)
    if netmask_length > MAX_NETMASK_LENGTH
      return "NetMaskLength(#{netmask_length}) is not exist."
    end

    str = "Destination\t|\tNext hop\n"
    str += "--------------------------------------\n"
    
    if netmask_length != 0
      @db[netmask_length].each do |prefix, next_hop|
        str += IPv4Address.new(prefix).to_s
        str += "/"
        str += netmask_length.to_s
        str += "\t|\t"
        str += next_hop.to_s
        str += "\n"
      end
      return str
    end

    MAX_NETMASK_LENGTH.downto(0).each do |netmask_length|
      @db[netmask_length].each do |prefix, next_hop|
        str += IPv4Address.new(prefix).to_s
        str += "/"
        str += netmask_length.to_s
        str += "\t|\t"
        str += next_hop.to_s
        str += "\n"
      end
    end
    return str
  end

  def all_next_hop()
    ret = Array.new()
    MAX_NETMASK_LENGTH.downto(0).each do |netmask_length|
      @db[netmask_length].each do |prefix, next_hop|
        ret << next_hop
      end
    end
    return ret.uniq
  end
end
