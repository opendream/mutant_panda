# Merb::Router is the request routing mapper for the merb framework.

Merb.logger.info("Compiling routes...")
Merb::Router.prepare do |r|
  r.match("/new(.:format)", :method => :get).to(:controller => "assets", :action => "new")
#   r.match("/new(.:format)", :method => :post).to(:controller => "assets", :action => "new")
  r.match("/form(.:format)", :method => :get).to(:controller => "assets", :action => "form")  # testing only
  r.match("/upload/:id", :method => :post).to(:controller => "assets", :action => "upload")
  r.match("/assets/:id(.:format)", :method => :get).to(:controller => "assets", :action => "show")
  r.match("/assets/:id(.:format)", :method => :delete).to(:controller => "assets", :action => "delete")
  r.match("/info(.:format)").to(:controller => "assets", :action => "info")
  r.match("/").to(:controller => "assets", :action => "info")
end
