require 'erb' # config templates
require 'yaml' # DB in a file
require 'ipaddress' # ip validation
require 'archive/zip' # zip stuff

# global variables https://stackoverflow.com/questions/12112765/how-to-reference-global-variables-and-class-variables

# initialize variables that are usually set in 10-globals.yml
# TODO find alternative way for these global variables
$lede_version=''
$download_base=''
$image_base=''
$platform=''
$platform_type=''

# src https://stackoverflow.com/a/27127342
def gen_timestamp()
  return Time.new.strftime ("%Y-%m-%d-%H-%M-%L")
end

def get_temba_version()
  # get latest commit -> src https://stackoverflow.com/questions/949314/how-to-retrieve-the-hash-for-the-current-commit-in-git
  current_commit = `git log --pretty=format:'%h' -n 1` || ''
  # get branch -> src https://stackoverflow.com/a/12142066
  # get rid of new line -> src https://stackoverflow.com/questions/7533318/get-rid-of-newline-from-shell-commands-in-ruby
  #current_branch = `git rev-parse --abbrev-ref HEAD`.chop || ''
  temba_version = "temba " + current_commit + "\n"
  return temba_version
end

def read_vars(myPath)
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
  nodes = YAML.load_file(allfile)
  nodes['temba_version'] = get_temba_version()
  return nodes
end

# generate all nodes defined in yaml configuration
def generate_all(myPath)
  nodes = read_vars(myPath)

  # src https://stackoverflow.com/a/32230037
  nodes['network'].each {|k, v|
    # convert key of the entire subarray as value node_name
    v['node_name'] = k
    prepare_global_variables(v, myPath)
    generate_node(v, myPath)
  }
end

def prepare_global_variables(node_cfg, myPath)
  $lede_version = node_cfg['lede_version']
  check_variable('lede_version', $lede_version)
  $platform = node_cfg['platform']
  check_variable('platform', $platform)
  $platform_type = node_cfg['platform_type']
  check_variable('platform_type', $platform_type)
  if node_cfg['image_base_type'] == 'lime-sdk'
    # this is the path given by lime-sdk
    $image_base = myPath + node_cfg['image_base_limesdk'] + '/' + "#{$lede_version}/#{$platform}/#{$platform_type}/ib"
  elsif node_cfg['image_base_type'] == 'path'
    $image_base = myPath + node_cfg['image_base']
  elsif node_cfg['image_base_type'] == 'official'
    $download_base = "https://downloads.lede-project.org/releases/#{$lede_version}/targets/#{$platform}/#{$platform_type}/"
    $image_base = myPath + "lede-imagebuilder-#{$lede_version}-#{$platform}-#{$platform_type}.Linux-x86_64"
    prepare_official_ib()
  end
  check_variable('image_base', $image_base)
end

def check_variable(varname, var)
  if var == '' || var.nil?
    raise varname + ' variable is empty'
  end
end

def generate_node(node_cfg, myPath)

  node_name = node_cfg['node_name']

  if $debug_erb
    dir_name = myPath + "debug-" + node_name
  else
    dir_name = "#{$image_base}/files_generated"
  end

  prepare_directory(dir_name, myPath + node_cfg['filebase'] || 'files')

  # SSID is guifi.net/node_name, truncated to the ssid limit (32 characters)
  wifi_ssid_base = node_cfg['wifi_ssid_base']
  node_cfg['wifi_ssid'] = (wifi_ssid_base + node_name).slice(0,32)

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

  return generate_firmware(node_cfg, myPath)

end

def prepare_directory(dir_name,filebase)
  # Clean up
  FileUtils.rm_r dir_name if File.exists? dir_name
  FileUtils.rm_r dir_name + '-template' if File.exists? dir_name + '-template'
  
  # Prepare (copy recursively the directory preserving permissions and dereferencing symlinks)
  system("cp -rpL " + filebase + " " + dir_name)

  # create dinamically a file to identify temba firmware with specific branch and commit

  temba_file = dir_name + "/etc/temba"

  temba_version = get_temba_version()

  # src https://stackoverflow.com/questions/2777802/how-to-write-to-file-in-ruby#comment24941014_2777863
  File.write(temba_file, temba_version)

  FileUtils.cp_r dir_name, dir_name + '-template'
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
  # rails require binding context -> src https://blog.revathskumar.com/2014/10/ruby-rendering-erb-template.html
  File.open(base, 'w') { |file| file.write(template.result(binding)) }
  FileUtils.rm erb
end

def generate_firmware(node_cfg, myPath)

  # everything goes to tmp. when zip file is finished it goes to parent directory
  out_dir_base = myPath + 'output/tmp'

  # src https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby
  unless File.exists? out_dir_base
    # src https://stackoverflow.com/questions/5020710/copy-a-file-creating-directories-as-necessary-in-ruby
    FileUtils.mkdir_p out_dir_base
  end

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


  # notes for the output file
  notes = node_cfg['notes']
  if(notes)
    notes = '__' + notes.gsub(' ', '-')
  else
    notes = ''
  end

  if node_cfg.key? 'timestamp'
    timestamp = node_cfg['timestamp']
  else
    timestamp = gen_timestamp()
  end

  out_dir = out_dir_base + '/' + node_name + '_' + timestamp
  Dir.mkdir out_dir

  zipfile = "#{out_dir_base}/#{node_name}_#{timestamp}.zip"

  # different platforms different names in output file
  if "#{$platform}-#{$platform_type}" == "x86-64"
    out_path = "#{out_dir}/#{node_name}#{notes}-combined-ext4.img.gz"
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-combined-ext4.img.gz",
      out_path)

    # this requires so much space and is slow
    #system("gunzip -f -k #{out_dir}/#{node_name}-combined-ext4.img.gz")

    Archive::Zip.archive(zipfile, out_path)
  else
    out_path = {'sysupgrade' => "#{out_dir}/#{node_name}#{notes}-sysupgrade.bin",
                'factory'    => "#{out_dir}/#{node_name}#{notes}-factory.bin"}
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-sysupgrade.bin",
      out_path['sysupgrade'])
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-factory.bin",
      out_path['factory'])

    # compact both files in a zip
    Archive::Zip.archive(zipfile, out_path['sysupgrade'])
    Archive::Zip.archive(zipfile, out_path['factory'])
  end

  # add README to explain the contents of the zipfile)
  File.write( out_dir + '/README.txt', 'Contained files:

- *combined-ext4.img.gz: special image in case you built x86_64 architecture. You have to uncompress it (warning: 7 MB => 200 MB)
- *sysupgrade.bin: use it if you are comming from openwrt firmware
- *factory.bin: use it if you are comming from stock/OEM/factory firmware
- variables.yml: the variables that defined the firmware you got
- etc: /etc directory that is inside this firmware
- etc-template: /etc directory without applying variables.yml (in case you want to know what is exactly templating)
')
  Archive::Zip.archive(zipfile, out_dir + '/README.txt')
  # add etc
  FileUtils.cp_r "#{$image_base}/files_generated/etc", out_dir
  Archive::Zip.archive(zipfile, out_dir + '/etc')
  # add etc-template
  FileUtils.cp_r "#{$image_base}/files_generated-template/etc", out_dir + '/etc-template'
  Archive::Zip.archive(zipfile, out_dir + '/etc-template')
  # add variables.yml
  File.write( out_dir + '/variables.yml', node_cfg.to_yaml)
  Archive::Zip.archive(zipfile, out_dir + '/variables.yml')

  # when the file is ready, put it in the place to be downloaded
  FileUtils.mv(zipfile, "#{out_dir_base}/..")

  puts("\ntemba finished succesfully!")
  return zipfile
end

def prepare_official_ib()
  ib_archive = "#{$image_base}.tar.xz"
  unless File.exists? $image_base
    # assumed file is already downloaded
    system("wget #{$download_base}#{ib_archive}") unless File.exists? ib_archive
    system("tar xf #{ib_archive}")
  end
end
