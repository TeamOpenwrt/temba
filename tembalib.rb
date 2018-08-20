require 'erb'
require 'yaml'
require 'ipaddress'

# global variables https://stackoverflow.com/questions/12112765/how-to-reference-global-variables-and-class-variables

# initialize variables that are usually set in 10-globals.yml
$lede_version=''
$download_base=''
$image_base=''
$platform=''
$platform_type=''

def read_config(myPath)
  # file that merges all yaml files
  allfile = myPath + 'all.yml'
  if File.exists? allfile
    File.delete(allfile)
  end
  all_f = File.open(allfile, 'a')

  # look for all yml files
  Dir[myPath + '*.yml'].sort.each {|file|
    # read file -> src https://stackoverflow.com/a/131001
    temp = File.open(file, 'r').read
    all_f.write(temp)
  }

  all_f.close

  YAML.load_file(allfile)
end

def generate_all()
  nodes = read_config('./')

  # src https://stackoverflow.com/a/32230037
  nodes['network'].each {|k, v|
    # convert key of the entire subarray as value node_name
    v['node_name'] = k
    prepare_global_variables(v)
    generate_node(v)
  }
end

def prepare_global_variables(node_cfg)
  $lede_version = node_cfg['lede_version']
  check_variable('lede_version', $lede_version)
  $platform = node_cfg['platform']
  check_variable('platform', $platform)
  $platform_type = node_cfg['platform_type']
  check_variable('platform_type', $platform_type)
  if node_cfg['image_base_type'] == 'lime-sdk'
    # this is the path given by lime-sdk
    $image_base = node_cfg['image_base_limesdk'] + '/' + "#{$lede_version}/#{$platform}/#{$platform_type}/ib"
  elsif node_cfg['image_base_type'] == 'path'
    $image_base = node_cfg['image_base']
  elsif node_cfg['image_base_type'] == 'official'
    $download_base = "https://downloads.lede-project.org/releases/#{$lede_version}/targets/#{$platform}/#{$platform_type}/"
    $image_base = "lede-imagebuilder-#{$lede_version}-#{$platform}-#{$platform_type}.Linux-x86_64"
    prepare_official_ib()
  end
  check_variable('image_base', $image_base)
end

def check_variable(varname, var)
  if var == '' || var.nil?
    raise varname + ' variable is empty'
  end
end

def generate_node(node_cfg)

  node_name = node_cfg['node_name']

  if $debug_erb
    dir_name = "./debug-" + node_name
  else
    dir_name = "#{$image_base}/files_generated"
  end

  prepare_directory(dir_name, node_cfg['filebase'] || 'files')

  # SSID is guifi.net/node_name, truncated to the ssid limit (32 characters)
  wifi_ssid_base = node_cfg['wifi_ssid_base']
  node_cfg['wifi_ssid'] = (wifi_ssid_base + node_name).slice(0,32)
  #raise node_cfg['wifi_ssid'].inspect

  # avoid redundant data entry in yaml (bmx6_tun4 in CIDR vs ip4 and netmask4)
  bmx6_tun4 = node_cfg['bmx6_tun4']
  temp_ip, temp_netmask = bmx6_tun4.split("/")

  # TODO Need newer version of gem -> src https://github.com/ipaddress-gem/ipaddress/blob/master/lib/ipaddress.rb#L157-L161
  #unless IPAddress.valid_ipv4_subnet? bmx6_tun4
  unless IPAddress.valid_ipv4?(temp_ip) && (!(temp_netmask =~ /\A([12]?\d|3[0-2])\z/).nil? || IPAddress.valid_ipv4_netmask?(temp_netmask))
    raise 'invalid IP address'
  end

  ip4 = IPAddress::IPv4.new bmx6_tun4
  node_cfg['ip4'] = ip4.address
  node_cfg['netmask4'] = ip4.netmask

  #Evaluate templates
  locate_erb(dir_name, node_cfg)

  generate_firmware(node_cfg)

end

def prepare_directory(dir_name,filebase)
  # Clean up
  FileUtils.rm_r dir_name if File.exists? dir_name
  
  # Prepare (copy recursively the directory preserving permissions and dereferencing symlinks)
  system("cp -rpL " + filebase + " " + dir_name)

  # create dinamically a file to identify temba firmware with specific branch and commit

  temba_file = dir_name + "/etc/temba"
  # get latest commit -> src https://stackoverflow.com/questions/949314/how-to-retrieve-the-hash-for-the-current-commit-in-git
  current_commit = `git log --pretty=format:'%h' -n 1`
  # get branch -> src https://stackoverflow.com/a/12142066
  # get rid of new line -> src https://stackoverflow.com/questions/7533318/get-rid-of-newline-from-shell-commands-in-ruby
  current_branch = `git rev-parse --abbrev-ref HEAD`.chop
  temba_content = "temba " + current_commit + "\n"
  # src https://stackoverflow.com/questions/2777802/how-to-write-to-file-in-ruby#comment24941014_2777863
  File.write(temba_file, temba_content)

end

def locate_erb(dir_name, node_cfg)
  Dir.glob("#{dir_name}/**/*.erb").each do |erb_file|
    basename = erb_file.gsub '.erb',''
    process_erb(node_cfg,erb_file,basename)
  end
end

def process_erb(node,erb,base)
  @node = node
  # enable trim mode -> src https://stackoverflow.com/questions/4632879/erb-template-removing-the-trailing-line
  template = ERB.new(File.new(erb).read, nil, '-')
  File.open(base, 'w') { |file| file.write(template.result) }
  FileUtils.rm erb
end

def generate_firmware(node_cfg)

  # check variables TODO improve
  node_name = node_cfg['node_name']
  check_variable('node_name', node_name)
  profile = node_cfg['profile']
  check_variable('profile', profile)
  packages = node_cfg['packages']
  check_variable('packages', packages)

  if $debug_erb
    print('Directory debug-', node_cfg['node_name'], "...  Done!\n")
    return
  end

  puts("\n\n\n\n\n    >>> make -C #{$image_base}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated\n\n\n\n\n")
  system("make -C #{$image_base}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated")

  # src https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby
  unless File.exists? 'bin'
    Dir.mkdir 'bin'
  end

  # notes in output file
  notes = node_cfg['notes']
  if(notes)
    notes = '__' + notes.gsub(' ', '-')
  else
    notes = ''
  end

  # different platforms different names in output file
  if "#{$platform}-#{$platform_type}" == "x86-64"
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-combined-ext4.img.gz",
      "bin/#{node_name}#{notes}-combined-ext4.img.gz")
    system("gunzip -f -k bin/#{node_name}-combined-ext4.img.gz")
  else
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-sysupgrade.bin",
      "bin/#{node_name}#{notes}-sysupgrade.bin")
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-factory.bin",
      "bin/#{node_name}#{notes}-factory.bin")
  end
end

def prepare_official_ib()
  ib_archive = "#{$image_base}.tar.xz"
  unless File.exists? $image_base
    # assumed file is already downloaded
    system("wget #{$download_base}#{ib_archive}") unless File.exists? ib_archive
    system("tar xf #{ib_archive}")
  end
end
