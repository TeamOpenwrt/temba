Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # form at root
  get '/', to: 'nodes#new', as: 'new_node'
  post '/', to: 'nodes#create', as: 'create_node'

end
