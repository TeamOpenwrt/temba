load '../tembalib.rb'

class NodesController < ApplicationController
  def new
    @node = Node.new
    @node.vars = read_vars('../') # load config for form
    @node.vars['temba_commit_ror'] = get_current_temba_commit()
  end

  # thanks https://stackoverflow.com/questions/22002020/how-to-download-file-with-send-file
  def download
    # are you blacklisting? -> https://guides.rubyonrails.org/security.html#file-uploads
    @download_params = params.require(:file)
    file_name = params['file'].split('/').last
    download = params['download']
    file_loc = "#{Rails.root}/../output/#{file_name}"
    if File.exists? file_loc
      if download == 'true'
        return send_file file_loc
      end
      # src https://guides.rubyonrails.org/layouts_and_rendering.html#rendering-text
      return render plain: "/download?file=#{file_name}&download=true"
    else
      return render plain: 'not available'
    end

  end

  def create
    @node = Node.new node_params
    @node.vars = read_vars('../') # load config for the procedure of building firmware
    @node.vars['temba_commit_ror'] = get_current_temba_commit()

    if @node.valid?

      target = @node.device
      device = @node.vars['devices'][target]
      device['node_name'] = @node.node_name
      device['wifi_channel'] = @node.wifi_channel
      device['ip4_cidr'] = @node.ip4_cidr

      device['timestamp'] = gen_timestamp()
      # force file provision to be template
      device['file_provision'] = 'template'

      # Use thread pool as compilation process must be one at a time
      # To enqueue a job to be performed as soon as the queueing system is free:
      CompileJob.perform_later(device)

      # src https://stackoverflow.com/a/8420078
      redirect_to new_node_url, notice: "Petition received to build node: #{device['node_name']}_#{device['timestamp']}"

    else

      # render page again with the entered values
      render :new

    end
  end

  # Only public methods are callable as actions. It is a best practice to lower the visibility of methods (with private or protected) which are not intended to be actions, like auxiliary methods or filters. -> src https://guides.rubyonrails.org/action_controller_overview.html#methods-and-actions
  private

  def node_params
    # strong parameters -> https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters
    return params.require(:node).permit(:device, :node_name, :wifi_channel, :ip4_cidr)
  end
end
