require "erb"
require "rake"
require 'yaml'

LEDE_VERSION="17.01.4"
# TODO this variables go to the devices.yml
PLATFORM="ar71xx"
PLATFORM_TYPE="generic"

# DOWNLOAD_BASE="https://downloads.lede-project.org/releases/#{LEDE_VERSION}/targets/#{PLATFORM}/#{PLATFORM_TYPE}/"
# IMAGE_BASE="lede-imagebuilder-#{LEDE_VERSION}-#{PLATFORM}-#{PLATFORM_TYPE}.Linux-x86_64"
# assumes files are already downloaded
DOWNLOAD_BASE="./lede-imagebuilder-17.01.4-ar71xx-generic.Linux-x86_64.tar.xz"
IMAGE_BASE="./lede-imagebuilder-17.01.4-ar71xx-generic.Linux-x86_64"

task :default => :generate_all
# IB (Image Builder)
task :generate_all => :install_ib do
#task :generate_all do

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

  nodes.values.each {|v| generate_node(v)}
end

def generate_node(node_cfg)
  dir_name = "#{IMAGE_BASE}/files_generated"
  
  prepare_directory(dir_name,node_cfg['filebase'] || 'files')
  #Evaluate templates
  Dir.glob("#{dir_name}/**/*.erb").each do |erb_file|
    basename = erb_file.gsub '.erb',''
    process_erb(node_cfg,erb_file,basename)
  end
  generate_firmware(node_cfg['node_name'], node_cfg['profile'], node_cfg['packages'])
  
end

def prepare_directory(dir_name,filebase)
  # Clean up
  FileUtils.rm_r dir_name if File.exists? dir_name
  
  # Prepare
  FileUtils.cp_r filebase, dir_name, :preserve => true

  # Test,debug
  FileUtils.cp_r filebase, "./test", :preserve => true
end

def process_erb(node,erb,base)
  @node = node
  template = ERB.new File.new(erb).read
  File.open(base, 'w') { |file| file.write(template.result) }
  FileUtils.rm erb
end

def generate_firmware(node_name,profile,packages)
  puts("\n\n\n\n\n    >>> make -C #{IMAGE_BASE}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated\n\n\n\n\n")
  system("make -C #{IMAGE_BASE}  image PROFILE=#{profile} PACKAGES='#{packages}'  FILES=./files_generated")

  FileUtils.mv(
    "#{IMAGE_BASE}/bin/targets/#{PLATFORM}/#{PLATFORM_TYPE}/lede-#{LEDE_VERSION}-#{PLATFORM}-#{PLATFORM_TYPE}-#{profile}-squashfs-sysupgrade.bin",
    "bin/#{node_name}-sysupgrade.bin")
  FileUtils.mv(
    "#{IMAGE_BASE}/bin/targets/#{PLATFORM}/#{PLATFORM_TYPE}/lede-#{LEDE_VERSION}-#{PLATFORM}-#{PLATFORM_TYPE}-#{profile}-squashfs-factory.bin",
    "bin/#{node_name}-factory.bin")
end

task :install_ib do 
  ib_archive = "#{IMAGE_BASE}.tar.xz"
  unless File.exists? IMAGE_BASE
    # assumed file is already downloaded
    #system("wget #{DOWNLOAD_BASE}#{ib_archive}") unless File.exists? ib_archive
    system("tar xf #{ib_archive}")
  end
end
