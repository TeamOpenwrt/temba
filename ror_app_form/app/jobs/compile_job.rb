class CompileJob < ActiveJob::Base
  def perform(device)
    prepare_global_variables(device, '../')
    myFile = generate_node(device, '../')
  end
end
