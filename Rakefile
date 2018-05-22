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
task :generate_all => :install_sdk do
#task :generate_all do

  # #there are no secrets at the moment
  # if (! (File.exists? 'secrets.yml'))
  #   raise "\n \t >>> Please decrypt secrets.yml.gpg first \n\n\n"
  # end
  # secrets = YAML.load_file("secrets.yml")

  # Default Generate config for all nodes
  nodes = YAML.load_file("nodes.yml")
  #nodes.values.each {|v| generate_node(v,secrets)}
  nodes.values.each {|v| generate_node(v)}
end

#there are no secrets at the moment
#def generate_node(node_cfg,secrets)
def generate_node(node_cfg)
  dir_name = "#{IMAGE_BASE}/files_generated"
  
  prepare_directory(dir_name,node_cfg['filebase'] || 'files')
  #Evaluate templates
  Dir.glob("#{dir_name}/**/*.erb").each do |erb_file|
    basename = erb_file.gsub '.erb',''
    #process_erb(node_cfg,erb_file,basename,secrets)
    process_erb(node_cfg,erb_file,basename)
  end
  generate_firmware(node_cfg['node_name'], node_cfg['profile'], node_cfg['packages'])
  
end

def prepare_directory(dir_name,filebase)
  # Clean up
  FileUtils.rm_r dir_name if File.exists? dir_name
  
  # Prepare
  FileUtils.cp_r filebase, dir_name, :preserve => true
end

#def process_erb(node,erb,base,secrets)
def process_erb(node,erb,base)
  @node = node
  # @secrets = secrets
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

task :install_sdk do 
  sdk_archive = "#{IMAGE_BASE}.tar.xz"
  unless File.exists? IMAGE_BASE
    # assumed file is already downloaded
    #system("wget #{DOWNLOAD_BASE}#{sdk_archive}") unless File.exists? sdk_archive
    system("tar xf #{sdk_archive}")
  end
end
