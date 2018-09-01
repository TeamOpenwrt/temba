(function() {
  var actioncable_methods

  actioncable_methods = {
    connected: function() {
      console.log('connected to temba form')
      App.online.update_users_counter()
    },
    disconnected: function() {
      App.cable.subscriptions.remove(this)
      this.perform('unsubscribed')
    },
    received: function(data) {
      var val
      // Called when there's incoming data on the websocket for this channel
      val = data.counter - 1 // just count other users
      //update "users_counter"-element in view:
      document.getElementById('online_users').textContent = val

      //console.log('new event')
    },
    update_users_counter() {
      this.perform('update_users_counter')
    }
  }

  App.online = App.cable.subscriptions.create({
    channel: "OnlineChannel"
  }, actioncable_methods)

}).call(this)
