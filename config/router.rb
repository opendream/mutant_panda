# Merb::Router is the request routing mapper for the merb framework.

Merb.logger.info("Compiling routes...")
Merb::Router.prepare do |r|
  r.match("/new.js", :method => :get).to(:controller => "assets", :action => "new", :format => :json)  # can use get or post
  r.match("/new.js", :method => :post).to(:controller => "assets", :action => "new", :format => :json)
  r.match("/form.html", :method => :get).to(:controller => "assets", :action => "form", :format => :html)
  r.match("/upload/:id", :method => :post).to(:controller => "assets", :action => "upload")
  r.match("/assets/:id.js", :method => :get).to(:controller => "assets", :action => "show", :format => :json)
  r.match("/assets/:id.js", :method => :delete).to(:controller => "assets", :action => "delete", :format => :json)
  r.match("/info.js").to(:controller => "assets", :action => "info", :format => :json)
  r.match("/").to(:controller => "assets", :action => "info", :format => :json)
end
