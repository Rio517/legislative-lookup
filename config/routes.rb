Tigress::Application.routes.draw do
  match '/' => 'districts#index'
  match 'districts/lookup_map_polygons.:format' => 'districts#lookup_map_polygons'
  match '/state_maps' => 'districts#state_maps'
  # match 'districts/polygon.:format' => 'districts#polygon'
  match '/lookup.:format' => 'districts#lookup', :as => :lookup
end
