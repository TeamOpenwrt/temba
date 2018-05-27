require 'erb'
require 'yaml'

def generate_all()
  # file that merges all yaml files
  allfile = 'all.yml'
  if File.exists? allfile
    File.delete(allfile)
  end
  all_f = File.open(allfile, 'a')

  Dir['*.yml'].sort.each {|file|
    # read file -> src https://stackoverflow.com/a/131001
    temp = File.open(file, 'r').read
    all_f.write(temp)
  }

  all_f.close

  nodes = YAML.load_file(allfile)

  nodes['network'].values.each {|v|
    prepare_global_variables(v)
    generate_node(v)
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
    $image_base = nodes['image_base_limesdk'] + "#{$lede_version}/#{$platform}/#{$platform_type}/ib"
    puts('this test: ' + $image_base)
  elsif nodes['image_base_type'] == 'path'
    $image_base = nodes['image_base']
  elsif nodes['image_base_type'] == 'official'
    $download_base="https://downloads.lede-project.org/releases/#{$lede_version}/targets/#{$platform}/#{$platform_type}/"
    $image_base="lede-imagebuilder-#{$lede_version}-#{$platform}-#{$platform_type}.Linux-x86_64"
    puts('image base ' + $image_base)
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
  dir_name = "#{$image_base}/files_generated"
  
  prepare_directory(dir_name,node_cfg['filebase'] || 'files')
  #Evaluate templates
  Dir.glob("#{dir_name}/**/*.erb").each do |erb_file|
    basename = erb_file.gsub '.erb',''
    process_erb(node_cfg,erb_file,basename)
  end

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
  
  # Prepare
  FileUtils.cp_r filebase, dir_name, :preserve => true

  # Test,debug
  FileUtils.cp_r filebase, './test', :preserve => true
end

def process_erb(node,erb,base)
  @node = node
  template = ERB.new File.new(erb).read
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

  FileUtils.mv(
    "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-sysupgrade.bin",
    "bin/#{node_name}-sysupgrade.bin")
  FileUtils.mv(
    "#{$image_base}/bin/targets/#{$platform}/#{$platform_type}/lede-#{$lede_version}-#{$platform}-#{$platform_type}-#{profile}-squashfs-factory.bin",
    "bin/#{node_name}-factory.bin")
end

def prepare_official_ib()
  ib_archive = "#{$image_base}.tar.xz"
  puts('i39242j3942938j')
  unless File.exists? $image_base
    # assumed file is already downloaded
    system("wget #{$download_base}#{ib_archive}") unless File.exists? ib_archive
    system("tar xf #{ib_archive}")
  end
end
