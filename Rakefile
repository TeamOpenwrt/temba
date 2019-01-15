# how it works rake: http://www.stuartellis.name/articles/rake/
require 'rake'
load 'tembalib.rb'

task :default => :generate_all
task :generate_all do
  $debug_erb = false
  generate_all('./')
end

# apply only configuration template for the last node and copy it to debug directory
task :debug_erb do
  $debug_erb = true
  generate_all('./')
end
# alias to debug -> src https://stackoverflow.com/a/7661613
task :d => :debug_erb
