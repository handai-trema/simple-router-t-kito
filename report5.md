#第五回 課題: ルータのCLIを作ろう

##提出者
氏名：木藤嵩人

##課題内容
```
ルータのコマンドラインインタフェース (CLI) を作ろう。

次の操作ができるコマンドを作ろう。

* ルーティングテーブルの表示
* ルーティングテーブルエントリの追加と削除
* ルータのインタフェース一覧の表示
* そのほか、あると便利な機能
```

##解答
##1.ルーティングテーブルの表示
`./lib/simple_router.rb`に`dump_routing_table`メソッドを追加した。`dump_routing_table`メソッドはRoutingTableクラスに実装したdumpメソッドの戻り値をそのまま返すようになっている。
```
  def dump_routing_table(netmask_length=0)
    return @routing_table.dump(netmask_length)
  end
```
RoutingTableクラスに実装したdumpメソッドを以下に示す。dumpメソッドでは、初期引数としてDUMP_ALL_NETMASK_LENGTH(0)を与えている。初期引数のまま実行が行われた場合は、ルーティングテーブルの中身すべてを表示する。1～MAX_NETMASK_LENGTHの値が与えられた場合は、そのサブネットマスクに該当するルーティングテーブルのみを表示する。
```
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
```
コマンドの仕様は以下のようになっている。
```
SYNOPSIS
    simple_router [global options] dump_routing_table [command options] 

COMMAND OPTIONS
    -S, --socket_dir=arg     - Location to find socket files (default: /tmp)
    -n, --netmask_length=arg - (default: none)
```
動作検証に結果については次項に記述する。

##2.ルーティングテーブルエントリの追加と削除
`./lib/simple_router.rb`に`add_entry_routing_table`メソッドと`delete_entry_routing_table`メソッドを追加した。
```
  def add_entry_routing_table(destination, netmask_length, next_hop)
    options = {
      :destination => destination,
      :netmask_length => netmask_length,
      :next_hop => next_hop
    }
    msg = @routing_table.add(options)
    return msg 
  end

  def delete_entry_routing_table(destination, netmask_length)
    options = {
      :destination => destination,
      :netmask_length => netmask_length
    }
    @routing_table.delete(options)
  end
```
ここで、RoutingTableクラスのaddメソッドとdeleteメソッドを呼び出している。addメソッドについては既存のものがあったが、ポートのIPアドレスと次の宛先IPアドレスのネットワークアドレスが異なる場合でも設定が可能であったため、デフォルトルート以外の設定を行う際に、ネットワークアドレスが異なる場合は設定を行わないように変更した。また、設定の結果を通知するようにした。deleteメソッドは存在しないため、新規に実装した。プログラムは以下のようになっている。
```
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
```
各コマンドの仕様は以下のようになっている。
```
NAME
    add_entry - Add the routing table entry

SYNOPSIS
    simple_router [global options] add_entry [command options] destination_ip netmask_length next_hop_ip

COMMAND OPTIONS
    -S, --socket_dir=arg - Location to find socket files (default: /tmp)
```
```
NAME
    delete_entry - Delete the routing table entry

SYNOPSIS
    simple_router [global options] delete_entry [command options] destination_ip netmask_length

COMMAND OPTIONS
    -S, --socket_dir=arg - Location to find socket files (default: /tmp)
```
各コマンドについて動作検証を行った。まず起動直後に`dump_routing_table`を用いてルーティングテーブルを表示した。
```
$ ./bin/simple_router dump_routing_table
Destination | Next hop
--------------------------------------
0.0.0.0/0 | 192.168.1.2
```
次にオプションを試す。ネットマスク長24のものについて表示を行った。
```
$ ./bin/simple_router dump_routing_table -n 24
Destination | Next hop
--------------------------------------
```
エントリが存在しないため、エントリは表示されない。続いて`add_entry_routing_table`メソッドを用いてエントリを追加し、ルーティングテーブルを表示した。
```
$ ./bin/simple_router add_entry 192.168.2.3 24 192.168.2.2
success
$ ./bin/simple_router dump_routing_table
Destination | Next hop
--------------------------------------
192.168.2.0/24  | 192.168.2.2
0.0.0.0/0 | 192.168.1.2
```
エントリが追加されていることが確認できた。次にネットマスク長24のエントリが追加されたので、オプションを使用して表示を行った。
```
$ ./bin/simple_router dump_routing_table -n 24
Destination | Next hop
--------------------------------------
192.168.2.0/24  | 192.168.2.2
```
ネットマスク長が24のエントリのみ表示されていることが確認できた。

##3.ルータのインターフェース一覧の表示
`./lib/simple_router.rb`に`dump_interface`メソッドを追加した。プログラムは以下のようになっている。
```
  def dump_interface()
    str = "Port number\t|\tMac address\t\t|\tIP address\n"
    str += "---------------------------------------------------------------------------\n"
    Interface.each do |each|
      str += each.port_number.to_s
      str += "\t\t|\t"
      str += each.mac_address.to_s
      str += "\t|\t"
      str += each.ip_address.to_s
      str += "/"
      str += each.netmask_length.to_s
      str += "\n"
    end
    return str
  end
```
コマンドの実装については、ルーティングテーブルを表示する場合と同様である。実行して結果を確認したところ、confファイルの設定どおりの結果が出力されたことが確認できた。
```
$ ./bin/simple_router dump_interface
Port number | Mac address   | IP address
---------------------------------------------------------------------------
1   | 01:01:01:01:01:01 | 192.168.1.1/24
2   | 02:02:02:02:02:02 | 192.168.2.1/24
```
