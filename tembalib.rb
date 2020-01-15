require 'pry' # for debugging use a line as `binding.pry` src https://stackoverflow.com/questions/1144560/how-do-i-drop-to-the-irb-prompt-from-a-running-script
require 'erb' # config templates
require 'yaml' # DB in a file
require 'ipaddress' # ip validation
require 'archive/zip' # zip stuff

# global variables https://stackoverflow.com/questions/12112765/how-to-reference-global-variables-and-class-variables

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

  # init firmware paths
  fw_paths = []
  # src https://stackoverflow.com/a/32230037
  nodes['network'].each {|k, v|
    # convert key of the entire subarray as value node_name
    v['node_name'] = k
    # we want all nodes to include these variables (they can be overridden)
    v_n = prepare_global_variables(v, myPath)
    zipfile = generate_node(v_n, myPath)
    fw_paths.push(zipfile)
  }
  if fw_paths.length > 1
    puts("------------------------------------------------")
    puts("\nSUMMARY of all temba nodes generated\n\n")
    fw_paths.map { |p| puts "  #{__dir__}/output/#{File.basename(p)}" }
    puts("\n")
  end
end

def prepare_global_variables(node_cfg, myPath)
  openwrt_version = node_cfg['openwrt_version']
  check_var('openwrt_version', openwrt_version)
  openwrt_number = openwrt_version.split('.')[0]
  node_cfg['openwrt_number'] = openwrt_number
  openwrt = node_cfg['openwrt']
  check_var('openwrt', openwrt)
  # check coherence between name and number
  if (openwrt_number == '17' && openwrt == 'openwrt') or (openwrt_number != '17' && openwrt == 'lede')
    puts "ERROR Mismatch:\n  Given openwrt_version=#{openwrt_version} openwrt=#{openwrt}\n  Expected openwrt_version=17.x openwrt=lede OR openwrt_version=18+ openwrt=openwrt"
    abort
  end
  platform = node_cfg['platform']
  check_var('platform', platform)
  platform_type = node_cfg['platform_type']
  check_var('platform_type', platform_type)
  # process the imagebuilder to use
  if node_cfg['image_base_type'] == 'local'
    ib_losu = node_cfg['image_base_local_suffix']
    if ! ib_losu.nil?
      ib_losu = "__#{node_cfg['image_base_local_suffix']}"
    else
      ib_losu = ''
    end
    node_cfg['image_base'] = myPath + "imagebuilder_local/#{openwrt}-imagebuilder-#{platform}-#{platform_type}.Linux-x86_64#{ib_losu}"
  elsif node_cfg['image_base_type'] == 'path'
    node_cfg['image_base'] = myPath + node_cfg['image_base']
  elsif node_cfg['image_base_type'] == 'official'
    node_cfg['download_base'] = "https://downloads.openwrt.org/releases/#{openwrt_version}/targets/#{platform}/#{platform_type}/"

    node_cfg['image_base'] = myPath + "#{openwrt}-imagebuilder-#{openwrt_version}-#{platform}-#{platform_type}.Linux-x86_64"

    # DEBUG
    # the path between different architectures is different (for example in cases of ar71xx and x86)
    #if node_cfg['platform'] == 'x86' or node_cfg['profile'] == 'tl-wdr4300-v1'
    #    node_cfg['image_base'] = myPath + "#{openwrt}-imagebuilder-#{openwrt_version}-#{platform}-#{platform_type}.Linux-x86_64"
    #else
    #    node_cfg['image_base'] = myPath + "#{openwrt}-imagebuilder-#{platform}-#{platform_type}.Linux-x86_64"
    #end
    prepare_official_ib(node_cfg)
  end
  check_var('image_base', node_cfg['image_base'])

  # check that the imagebuilder to use is found
  raise "\nERROR: #{node_cfg['image_base']} not found\n\n" if ! Dir.exists? node_cfg['image_base']
  return node_cfg
end

# TODO check all varaibles with a for statement?
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
    dir_name = "#{node_cfg['image_base']}/files"
  end

  raise "\n\nERROR: filebase variable is empty\n\n" if node_cfg['filebase'].nil?
  prepare_directory(dir_name, myPath + node_cfg['filebase'], node_cfg)

  # SSID is guifi.net/node_name, truncated to the ssid limit (32 characters)
  wifi_ssid_base = node_cfg['wifi_ssid_base']
  # don't use unless -> src https://veerasundaravel.wordpress.com/2011/02/25/why-ruby-unless-doesnt-have-elsif-or-elsunless-option/
  if ! wifi_ssid_base.nil?
    node_cfg['wifi_ssid'] = (wifi_ssid_base + node_name).slice(0,32)
  elsif ! node_cfg['wifi_ssid'].nil?
    puts 'WARNING: "wifi_ssid_base" variable is undefined. Custom "wifi_ssid" is going to be used'
  end

  # avoid redundant data entry in yaml (ip4_cidr in CIDR vs ip4 and netmask4)
  ip4_cidr = node_cfg['ip4_cidr']
  unless ip4_cidr.nil?
    temp_ip, temp_netmask = ip4_cidr.split("/")

    # TODO Need newer version of gem -> src https://github.com/ipaddress-gem/ipaddress/blob/master/lib/ipaddress.rb#L157-L161
    #unless IPAddress.valid_ipv4_subnet? ip4_cidr
    unless IPAddress.valid_ipv4?(temp_ip) && (!(temp_netmask =~ /\A([12]?\d|3[0-2])\z/).nil? || IPAddress.valid_ipv4_netmask?(temp_netmask))
      raise 'invalid IP address'
    end

    ip4 = IPAddress::IPv4.new ip4_cidr
    node_cfg['ip4'] = ip4.address
    node_cfg['netmask4'] = ip4.netmask
  end

  #Evaluate templates
  locate_erb(dir_name, node_cfg)

  return generate_firmware(node_cfg, myPath)

end

def prepare_directory(dir_name,filebase, node_cfg)

  # Clean up
  FileUtils.rm_r dir_name if File.exists? dir_name
  dir_name_template = File.dirname(dir_name) + '/files_template'
  FileUtils.rm_r dir_name_template if File.exists? dir_name_template

  # Prepare (copy recursively the directory preserving permissions and dereferencing symlinks)
  system('cp -rpL ' + filebase + ' ' + dir_name) or raise "\n\nERROR: Template failed to be copied. Maybe there is a broken symlink\n\n"


  # temba dynamic pseudorelease that appears as banner
  temba_version = ' Temba ' + get_current_temba_commit() + "\n"
  temba_hline = ' -----------------------------------------------------' + "\n"

  # create dinamically a file to identify temba firmware with specific branch and commit
  # src https://stackoverflow.com/questions/2777802/how-to-write-to-file-in-ruby#comment24941014_2777863

  # directory exists -> src https://stackoverflow.com/questions/1085218/how-to-check-if-a-given-directory-exists-in-ruby/1085260#1085260
  puts "\n\nWARNING! looks like there is no etc directory inside filebase path. That does not look good!\n\n" unless Dir.exists? node_cfg['filebase'] + '/etc/'
  # temba always put some files in /etc (independently of the template used) -> src https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby/19280532#19280532
  FileUtils.mkdir_p dir_name + '/etc/'

  File.write(dir_name + '/etc/temba_commit', get_current_temba_commit())
  File.write(dir_name + '/etc/temba_banner', temba_version + temba_hline)

  if node_cfg.key? 'timestamp'
    timestamp = node_cfg['timestamp']
  else
    timestamp = gen_timestamp()
  end

  # include variables in the yaml
  node_cfg['timestamp'] = timestamp
  node_cfg['temba_commit'] = get_current_temba_commit()
  node_cfg['temba_version'] = temba_version.strip
  # set a default password when it is indefined
  node_cfg['passwd'] = '13f' if node_cfg['passwd'].nil?
  # format password for /etc/shadow
  node_cfg['hashed_passwd'] = node_cfg['passwd'].crypt('$1$md5Salt$')
  # packages are generated through a merge of yaml arrays -> src https://stackoverflow.com/questions/24090177/how-to-merge-yaml-arrays
  # it is required to postprocess with flatten function in ruby, and to put the array as a string separated by whitespaces
  # packages can be repeated by different sets of 15-packages.yml
  node_cfg['packages'] = node_cfg['packages'].flatten.uniq.join(' ')

  File.write( dir_name + '/etc/temba_vars.yml', node_cfg.to_yaml)

  # duplicate directory in order to maintain a copy of erb variables
  FileUtils.cp_r dir_name, File.dirname(dir_name) + '/files_template'
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
    puts "Template error in file #{File.basename(erb)} of #{node['filebase']}: contains undefined variables.\n  #{e.message}"
    abort
  end
  FileUtils.rm erb
end

def generate_firmware(node_cfg, myPath)

  # everything goes to tmp. when zip file is finished it goes to parent directory
  out_dir_base = myPath + 'output/tmp'
  # src https://stackoverflow.com/questions/5020710/copy-a-file-creating-directories-as-necessary-in-ruby
  FileUtils.mkdir_p out_dir_base

  # check variables TODO improve
  node_name = node_cfg['node_name']
  check_var('node_name', node_name)
  profile = node_cfg['profile']
  profile_bin = node_cfg['profile_bin']
  # next is probably the situation for all target/linux/ar71xx/image/legacy.mk -> src https://bugs.openwrt.org/index.php?do=details&task_id=2061
  profile_bin = profile if node_cfg['profile_bin'].nil?
  check_var('profile', profile)
  packages = node_cfg['packages']
  check_var('packages', packages)

  if $debug_erb
    print('Directory debug-', node_cfg['node_name'], "...  Done!\n")
    return
  end

  image_base = node_cfg['image_base']

  # do small images in x86 architectures -> src https://stackoverflow.com/questions/7290871/ruby-how-to-replace-text-in-a-file/18913856#18913856
  if node_cfg['small_rootfs'].nil? || node_cfg['small_rootfs'] == false
  ib_config_path=node_cfg['image_base'] + '/.config'
  IO.write(ib_config_path, File.open(ib_config_path) do |f|
      #f.read.gsub(/CONFIG_TARGET_ROOTFS_PARTSIZE=.*$/, "CONFIG_TARGET_ROOTFS_PARTSIZE=32")
      # quits the default value (reduces from ~300 MB to ~50 MB) -> src https://forum.openwrt.org/t/how-to-set-root-filesystem-partition-size-on-x86-imabebuilder/4765
      f.read.gsub(/CONFIG_TARGET_ROOTFS_PARTSIZE=256/, "CONFIG_TARGET_ROOTFS_PARTSIZE=32")
    end
  )
  end

  make_cmd="make -C #{image_base} image PROFILE=#{profile} PACKAGES='#{packages}' FILES=./files"

  puts("\n\n\n\n\n    >>> #{make_cmd}\n\n\n\n\n")
  # throw error on system call -> src https://stackoverflow.com/a/18728161
  system(make_cmd) or raise "Openwrt build error. Check dependencies and requirements. Check consistency of:\n    #{image_base}\n    or the archive where came from #{File.basename(image_base)}.tar.xz"

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
  platform = node_cfg['platform']
  platform_type = node_cfg['platform_type']
  openwrt = node_cfg['openwrt']
  openwrt_version = node_cfg['openwrt_version']

  # TODO all this if block section should be highly refactored
  # different platforms different names in output file
  #if "#{platform}-#{platform_type}" == "x86-64"
  if "#{platform}" == "x86"
    out_path = "#{out_dir}/#{node_name}#{notes}-combined-ext4.img.gz"

    src_path = Dir.glob("#{image_base}/bin/targets/#{platform}/#{platform_type}/#{openwrt}*-#{platform}*-combined-ext4.img.gz")[0]

    if src_path.nil?
      raise '  ~> Target file does not exist, read previous lines about what happened. Does firmware fit this device?'
    end

    # TODO this differs from "else" situation because there is not "-#{profile_bin}", changes the final text, and there is no sysupgrade image (just one image)
    FileUtils.mv(src_path, out_path)

    # this requires so much space and is slow
    #system("gunzip -f -k #{out_dir}/#{node_name}-combined-ext4.img.gz")

    Archive::Zip.archive(zipfile, out_path)
  else
    out_path = {'sysupgrade' => "#{out_dir}/#{node_name}#{notes}-sysupgrade.bin",
                'factory'    => "#{out_dir}/#{node_name}#{notes}-factory.bin"}

    src_path = Dir.glob("#{image_base}/bin/targets/#{platform}/#{platform_type}/#{openwrt}*-#{platform}-#{platform_type}-#{profile_bin}-squashfs-sysupgrade.bin")[0]

    if src_path.nil?
      raise '  ~> Target file does not exist, read previous lines about what happened. Does firmware fit this device?'
    end

    # process sysupgrade image: move to a different directory and compact it
    # TODO in "path" situation (image builder from stratch) "-#{openwrt_version}" must not be there
    FileUtils.mv(src_path, out_path['sysupgrade'])

    # compact sysupgrade files in a zip
    Archive::Zip.archive(zipfile, out_path['sysupgrade'])

    # process factory image: move to a different directory and compact it
    # some devices does not have factory
    factory_path = Dir.glob("#{image_base}/bin/targets/#{platform}/#{platform_type}/#{openwrt}*-#{platform}-#{platform_type}-#{profile_bin}-squashfs-factory.bin")[0]
    if ! factory_path.nil?
      FileUtils.mv(factory_path, out_path['factory'])
      Archive::Zip.archive(zipfile, out_path['factory'])
    end

  end

  # add README to explain the contents of the zipfile)
  File.write( out_dir + '/README.txt', 'Contained files:

- *combined-ext4.img.gz: special image in case you built x86_64 architecture. You have to uncompress it (warning: 7 MB => 200 MB)
- *sysupgrade.bin: use it if you are comming from openwrt firmware
- *factory.bin: use it if you are comming from stock/OEM/factory firmware
- variables.yml: the variables that defined the firmware you got
- files: all files that are inside this firmware
- files_template: all files without applying variables.yml (in case you want to know what is exactly templating)
')
  Archive::Zip.archive(zipfile, out_dir + '/README.txt')
  # add etc
  FileUtils.cp_r "#{image_base}/files/", out_dir + '/files'
  Archive::Zip.archive(zipfile, out_dir + '/files')
  # add files_template
  FileUtils.cp_r "#{image_base}/files_template/", out_dir + '/files_template'
  Archive::Zip.archive(zipfile, out_dir + '/files_template')
  # add variables.yml
  File.write( out_dir + '/variables.yml', node_cfg.to_yaml)
  Archive::Zip.archive(zipfile, out_dir + '/variables.yml')

  # when the file is ready, put it in the place to be downloaded
  FileUtils.mv(zipfile, "#{out_dir_base}/..")

  puts("\ntemba firmware generated: #{__dir__}/output/#{File.basename(zipfile)}\n\n")

  return zipfile
end

# user should check consistency of image_base file and directory by itself
def prepare_official_ib(node_cfg)
  image_base = node_cfg['image_base']
  download_base = node_cfg['download_base']

  ib_archive = "#{image_base}.tar.xz"

  unless $debug_erb
    # rails case: ensure basename of ib_archive for concatenation, but place in the same place as temba cli
    system("wget -c #{download_base}#{File.basename(ib_archive)} -O #{ib_archive}") or raise "ERROR. Internet is unreachable or URL is incorrect. Variables: download_base=#{download_base}; ib_archive=#{ib_archive}\n \n"
    unless File.exists? image_base
      # tar to specific directory -> src https://www.tecmint.com/extract-tar-files-to-specific-or-different-directory-in-linux/
      system("tar xf #{ib_archive} --directory #{File.dirname(ib_archive)}") or raise "ERROR processing system call"
    end
  end
end
