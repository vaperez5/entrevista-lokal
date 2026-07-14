Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Catálogo: punto de entrada del flujo.
  resources :products, only: [ :index ]

  # Carrito. El carrito es único por sesión, así que es un recurso singular;
  # sus líneas cuelgan de él y se identifican por product_id.
  get    "cart",                   to: "cart#show",        as: :cart
  post   "cart/items",             to: "cart#add_item",    as: :cart_items
  patch  "cart/items/:product_id", to: "cart#update_item", as: :cart_item
  delete "cart/items/:product_id", to: "cart#remove_item",  as: :remove_cart_item

  # Confirmar la compra: convierte el carrito en una orden.
  post "checkout", to: "cart#checkout", as: :checkout

  resources :orders, only: [ :show ]

  # Defines the root path route ("/")
  root "products#index"
end
