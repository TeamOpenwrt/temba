load '../tembalib.rb'

class NodesController < ApplicationController
  def new
    @node = Node.new
    @node.vars = read_config('../') # load config for form
  end

  def create

    @node = Node.new node_params
    @node.vars = read_config('../') # load config for the procedure of building firmware

    if @node.valid?

      target = @node.device
      device = @node.vars['devices'][target]
      device['node_name'] = @node.node_name
      device['wifi_channel'] = @node.wifi_channel
      device['bmx6_tun4'] = @node.bmx6_tun4

      prepare_global_variables(device, '../')
      myFiles = generate_node(device, '../')

      # send_file -> src https://stackoverflow.com/questions/5535981/what-is-the-difference-between-send-data-and-send-file-in-ruby-on-rails
      send_file myFiles

      # this is a way to print a success message
      #redirect_to new_node_url, notice: "Message received, thanks!", send_file( file )

    else

      render :new

    end

  end

  # A lot Rails developers would put that node_params local variable in a private method, like so: (?)
  private

  def node_params
    return params.require(:node).permit(:device, :node_name, :wifi_channel, :bmx6_tun4)
  end
end
