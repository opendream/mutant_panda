# Go to http://wiki.merbivore.com/pages/init-rb

# # Autoload from lib
# $LOAD_PATH.unshift(Merb.root / "lib")
# Merb.push_path(:lib, Merb.root / "lib")  # uses **/*.rb as path glob.

require 'config/dependencies.rb'
 
use_orm :datamapper
use_test :rspec
use_template_engine :erb
 
Merb::Config.use do |c|
  c[:use_mutex] = false
  c[:session_store] = 'cookie'
  c[:session_id_key] = 'mutant_panda'
  c[:session_secret_key]  = '4d5e9b90d9e92c236a2300d718059aef3a9b9cbe'

  # identifies an instace of this web app in the emails it sends
  c[:instance_name]         = "killer_mutant_panda"
  
  # clients as name-key pairs
  c[:clients]               = [["client001", "key001"], ["client002", "key002"]]

  c[:tmp_dir]               = Merb.root / "tmp" / "assets"
  # Defaults to tmp within the Panda public directory. Optionally configurable   TODO: need this?
  # c[:public_tmp_path]       = "/var/www/images"
  # c[:public_tmp_url]        = "http://images.app.com"


  # Storage location for uploaded and encoded videos
  
  # for S3 storage:
  # c[:videos_store]          = :s3
  # c[:videos_domain]         = "s3.amazonaws.com/S3_BUCKET"
  # c[:s3_videos_bucket]      = "S3_BUCKET"
  # c[:access_key_id]         = "AWS_ACCESS_KEY"
  # c[:secret_access_key]     = "AWS_SECRET_ACCESS_KEY"
  
  # for filesystem storage:
  c[:store]                 = :filesystem
  c[:store_base_url]        = "localhost:4000/store"
  c[:store_dir]             = Merb.root / "public" / "store"
  
  # ================================================
  # Video stills
  # ================================================
  # This many thumbnail options will 
  # automatically be generated. The positions of these stills will be 
  # equally distributed throughout the video.

  c[:video_stills]          = 6 
  
  # ================================================
  # Application notification
  # ================================================
  # Panda will send your application a notfication when a video has finished
  # encoding. If it fails it will retry notification_retries times. These 
  # values are the defaults and should work for most applications.
  
  c[:notification_retries]  = 6
  c[:notification_frequency]= 10
  
  # ================================================
  # Get emailed error messages
  # ================================================
  # If you want errors emailed to you, when an encoding fails or panda fails 
  # to post a notification to your application, fill in both values:
  # c[:notification_email]    = "me@mydomain.com"
  # c[:noreply_from]          = "panda@mydomain.com"
end
 
Merb::BootLoader.before_app_loads do
  # Dependencies in lib - not autoloaded in time so require them explicitly
  require 'abstract_store'
  require 'file_store'
  require 's3_store'
  require 'data_mapper/types/b62encoded_random_index'
end
 
Merb::BootLoader.after_app_loads do
  # This will get executed after your app's classes have been loaded.
  
  unless Merb.environment =~ /test/
    require "config" / "mailer" if Merb::Config[:notification_email]
  end
  
  Store = case Merb::Config[:store]
    when :s3
      S3Store.new
    when :filesystem
      FileStore.new
    else
      raise RuntimeError, "Not properly configured, specify the strore (:filesystem or :s3) in config/init.rb"
  end
  
  FileUtils.mkdir_p Merb::Config[:tmp_dir]  # make sure the dir exists
  
#   Profile.warn_if_no_encodings unless Merb.env =~ /test/
end
