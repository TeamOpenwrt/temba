require 'pry' # for debugging use a line as `binding.pry` src https://stackoverflow.com/questions/1144560/how-do-i-drop-to-the-irb-prompt-from-a-running-script
require 'erb' # config templates
require 'yaml' # DB in a file
require 'ipaddress' # ip validation
# wait debian 10 -> https://packages.debian.org/search?keywords=ruby-archive-zip
#require 'archive/zip' # zip stuff

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

def get_current_temba_commit()
  # get latest commit -> src https://stackoverflow.com/questions/949314/how-to-retrieve-the-hash-for-the-current-commit-in-git
  current_commit = `git log --pretty=format:'%h' -n 1` || ''
  # get branch -> src https://stackoverflow.com/a/12142066
  # get rid of new line -> src https://stackoverflow.com/questions/7533318/get-rid-of-newline-from-shell-commands-in-ruby
  #current_branch = `git rev-parse --abbrev-ref HEAD`.chop || ''

  return current_commit
end

def read_vars(myPath)
  # file that merges all yaml files
  allfile = myPath + 'all.yml'
  if File.exists? allfile
    File.delete(allfile)
  end

  # helper: copy example files
  if ! File.exists? myPath + '10-globals.yml' and ! File.exists? myPath + '30-nodes.yml'
    puts("Looks like this is newly git cloned repository, copying example yaml files to use them:")
    system("cp -v #{myPath + '10-globals.yml.example'} #{myPath + '10-globals.yml'}")
    system("cp -v #{myPath + '30-nodes.yml.example'} #{myPath + '30-nodes.yml'}")
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
  check_var('lede_version', $lede_version)
  $platform = node_cfg['platform']
  check_var('platform', $platform)
  $platform_type = node_cfg['platform_type']
  check_var('platform_type', $platform_type)
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
  check_var('image_base', $image_base)
end

def check_var(varname, var)
  #unless defined? varname # TODO test this
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

  prepare_directory(dir_name, myPath + node_cfg['filebase'] || 'files', node_cfg)

  # SSID is guifi.net/node_name, truncated to the ssid limit (32 characters)
  wifi_ssid_base = node_cfg['wifi_ssid_base']
  unless wifi_ssid_base.nil?
    node_cfg['wifi_ssid'] = (wifi_ssid_base + node_name).slice(0,32)
  end

  # avoid redundant data entry in yaml (bmx6_tun4 in CIDR vs ip4 and netmask4)
  bmx6_tun4 = node_cfg['bmx6_tun4']
  unless bmx6_tun4.nil?
    temp_ip, temp_netmask = bmx6_tun4.split("/")

    # TODO Need newer version of gem -> src https://github.com/ipaddress-gem/ipaddress/blob/master/lib/ipaddress.rb#L157-L161
    #unless IPAddress.valid_ipv4_subnet? bmx6_tun4
    unless IPAddress.valid_ipv4?(temp_ip) && (!(temp_netmask =~ /\A([12]?\d|3[0-2])\z/).nil? || IPAddress.valid_ipv4_netmask?(temp_netmask))
      raise 'invalid IP address'
    end

    ip4 = IPAddress::IPv4.new bmx6_tun4
    node_cfg['ip4'] = ip4.address
    node_cfg['netmask4'] = ip4.netmask
  end

  #Evaluate templates
  locate_erb(dir_name + '/etc', node_cfg)

  return generate_firmware(node_cfg, myPath)

end

def prepare_directory(dir_name,filebase, node_cfg)

  # Clean up
  FileUtils.rm_r dir_name if File.exists? dir_name
  FileUtils.rm_r dir_name + '-template' if File.exists? dir_name + '-template'

  # Prepare (copy recursively the directory preserving permissions and dereferencing symlinks)
  system('cp -rpL ' + filebase + ' ' + dir_name)

  # create dinamically a file to identify temba firmware with specific branch and commit

  temba_file = dir_name + '/etc/temba'

  temba_version = "temba " + get_current_temba_commit() + "\n"

  # src https://stackoverflow.com/questions/2777802/how-to-write-to-file-in-ruby#comment24941014_2777863
  File.write(temba_file, temba_version)

  if node_cfg.key? 'timestamp'
    timestamp = node_cfg['timestamp']
  else
    timestamp = gen_timestamp()
  end

  # include variables in the yaml
  node_cfg['timestamp'] = timestamp
  node_cfg['temba_commit'] = get_current_temba_commit()
  # set a default password when it is indefined
  node_cfg['passwd'] = '13f' if node_cfg['passwd'].nil?
  # format password for /etc/shadow
  node_cfg['hashed_passwd'] = node_cfg['passwd'].crypt('$1$md5Salt$')

  File.write( dir_name + '/etc/temba_vars.yml', node_cfg.to_yaml)

  File.write(temba_file, temba_version)

  # duplicate directory in order to maintain a copy of erb variables
  FileUtils.cp_r dir_name + '/etc', dir_name + '/etc-template'
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
  safe_level = nil # TODO this erb operation might be insecure (specially for ror app?)  SecurityError: Insecure operation - eval
  template = ERB.new(File.new(erb).read, safe_level, '-')
  # catch error -> src https://medium.com/@farsi_mehdi/error-handling-in-ruby-part-i-557898185e2f
  begin
  # rails require binding context -> src https://blog.revathskumar.com/2014/10/ruby-rendering-erb-template.html
    File.open(base, 'w') { |file| file.write(template.result(binding)) }
  rescue KeyError => e
    puts "Template error in file #{File.basename(erb)} of #{node['filebase']}: contains undefined variables. #{e.message}"
  end
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
  check_var('node_name', node_name)
  profile = node_cfg['profile']
  check_var('profile', profile)
  packages = node_cfg['packages']
  check_var('packages', packages)

  if $debug_erb
    print('Directory debug-', node_cfg['node_name'], "...  Done!\n")
    return
  end

  puts("\n\n\n\n\n    >>> make -C #{$image_base}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated\n\n\n\n\n")
  # throw error on system call -> src https://stackoverflow.com/a/18728161
  system("make -C #{$image_base}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated") or raise "Openwrt build error. Check dependencies and requirements. Check consistency of:\n    #{$image_base}\n    #{$image_base}.tar.xz"

  # notes for the output file
  notes = node_cfg['notes']
  if(notes)
    notes = '__' + notes.gsub(' ', '-')
  else
    notes = ''
  end

  timestamp = node_cfg['timestamp']

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

    ##Archive::Zip.archive(zipfile, out_path)
    # create zip - ignore directory structure -> src https://stackoverflow.com/questions/9710141/create-zip-ignore-directory-structure
    system("zip -j -r #{zipfile} #{out_path}")
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
    ##Archive::Zip.archive(zipfile, out_path['sysupgrade'])
    system("zip -j -r #{zipfile} #{out_path['sysupgrade']}")
    ##Archive::Zip.archive(zipfile, out_path['factory'])
    system("zip -j -r #{zipfile} #{out_path['factory']}")
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
  ##Archive::Zip.archive(zipfile, out_dir + '/README.txt')
  system("zip -j -r #{zipfile} #{out_dir + '/README.txt'}")
  # add etc
  FileUtils.cp_r "#{$image_base}/files_generated/etc", out_dir
  ##Archive::Zip.archive(zipfile, out_dir + '/etc')
  system("cd #{out_dir}; zip -r #{'../' + File::basename(zipfile)} #{'./etc'}")
  # add etc-template
  FileUtils.cp_r "#{$image_base}/files_generated/etc-template", out_dir + '/etc-template'
  ##Archive::Zip.archive(zipfile, out_dir + '/etc-template')
  system("cd #{out_dir}; zip -r #{'../' + File::basename(zipfile)} #{'./etc-template'}")
  # add variables.yml
  File.write( out_dir + '/variables.yml', node_cfg.to_yaml)
  ##Archive::Zip.archive(zipfile, out_dir + '/variables.yml')
  system("zip -j -r #{zipfile} #{out_dir + '/variables.yml'}")

  # when the file is ready, put it in the place to be downloaded
  FileUtils.mv(zipfile, "#{out_dir_base}/..")

  puts("\ntemba finished succesfully!")
  return zipfile
end

# user should check consistency of image_base file and directory by itself
def prepare_official_ib()
  ib_archive = "#{$image_base}.tar.xz"

  # rails case: ensure basename of ib_archive for concatenation, but place in the same place as temba cli
  system("wget -c #{$download_base}#{File.basename(ib_archive)} -O #{ib_archive}") or raise "ERROR. Incorrect URL. Variables: download_base=#{$download_base}; ib_archive=#{ib_archive}\n \n"

  unless File.exists? $image_base
    system("tar xf #{ib_archive}")
  end
end
