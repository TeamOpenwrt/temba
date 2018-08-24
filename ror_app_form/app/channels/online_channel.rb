class OnlineChannel < ApplicationCable::Channel
  CHANNEL_NAME = 'online_channel'

  def subscribed
    stream_from CHANNEL_NAME
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    #update counter whenever a connection closes
    ActionCable.server.broadcast(CHANNEL_NAME, counter: count_unique_connections )
  end

  def update_users_counter
    ActionCable.server.broadcast(CHANNEL_NAME, counter: count_unique_connections )
  end

  private
  #Counts all users connected to the ActionCable server
  def count_unique_connections
    return ActionCable.server.connections.size
  end
end
