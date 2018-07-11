require 'erb'
require 'yaml'

# global variables https://stackoverflow.com/questions/12112765/how-to-reference-global-variables-and-class-variables

# initialize variables that are usually set in 10-globals.yml
$lede_version=''
$download_base=''
$image_base=''
$platform=''
$platform_type=''

def generate_all(debug_erb)
  # file that merges all yaml files
  allfile = 'all.yml'
  if File.exists? allfile
    File.delete(allfile)
  end
  all_f = File.open(allfile, 'a')

  # look for all yml files
  Dir['*.yml'].sort.each {|file|
    # read file -> src https://stackoverflow.com/a/131001
    temp = File.open(file, 'r').read
    all_f.write(temp)
  }

  all_f.close

  nodes = YAML.load_file(allfile)

  nodes['network'].values.each {|v|
    prepare_global_variables(v)
    if debug_erb
      debug_erb(v)
    else
      generate_node(v)
    end
  }
end

def prepare_global_variables(nodes)
  $lede_version = nodes['lede_version']
  check_variable('lede_version', $lede_version)
  $platform = nodes['platform']
  check_variable('platform', $platform)
  $platform_type = nodes['platform_type']
  check_variable('platform_type', $platform_type)
  if nodes['image_base_type'] == 'lime-sdk'
    # this is the path given by lime-sdk
    $image_base = nodes['image_base_limesdk'] + '/' + "#{$lede_version}/#{$platform}/#{$platform_type}/ib"
  elsif nodes['image_base_type'] == 'path'
    $image_base = nodes['image_base']
  elsif nodes['image_base_type'] == 'official'
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

def debug_erb(node_cfg)
  dir_name = "./debug-" + node_cfg['node_name']

  prepare_directory(dir_name,node_cfg['filebase'] || 'files')
  #Evaluate templates
  locate_erb(dir_name, node_cfg)
  print('Directory debug-', node_cfg['node_name'], "...  Done!\n")
end

def generate_node(node_cfg)
  dir_name = "#{$image_base}/files_generated"
  
  prepare_directory(dir_name,node_cfg['filebase'] || 'files')
  #Evaluate templates
  locate_erb(dir_name, node_cfg)

  # TODO check all node_name are unique
  node_name = node_cfg['node_name']
  check_variable('node_name', node_name)
  profile = node_cfg['profile']
  check_variable('profile', profile)
  packages = node_cfg['packages']
  check_variable('packages', packages)
  generate_firmware(node_name, profile, packages)
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
  temba_content = "temba " + current_branch + " " + current_commit + "\n"
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

def generate_firmware(node_name,profile,packages)
  puts("\n\n\n\n\n    >>> make -C #{$image_base}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated\n\n\n\n\n")
  system("make -C #{$image_base}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated")

  # src https://stackoverflow.com/questions/19280341/create-directory-if-it-doesnt-exist-with-ruby
  unless File.exists? 'bin'
    Dir.mkdir 'bin'
  end

  # different platforms different names
  if "#{$platform}-#{$platform_type}" == "x86-64"
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-combined-ext4.img.gz",
      "bin/#{node_name}-combined-ext4.img.gz")
    system("gunzip bin/#{node_name}-combined-ext4.img.gz")
  else
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-sysupgrade.bin",
      "bin/#{node_name}-sysupgrade.bin")
    FileUtils.mv(
      "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-factory.bin",
      "bin/#{node_name}-factory.bin")
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
