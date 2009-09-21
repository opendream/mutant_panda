# this class describes generic assets, or 'empty' assest (when nothing's uploaded yet)
# currently we want videos and images to use derived classes
# later maybe more derived classes may be added for particular asset types
# the queueing mechanism is already implemented in this class, it be in an abstract fashion

# An asset of the base type Asset has no derived assets and needs no further processing,
# if an asset need either of those a subclass of Asset has to be created for it. 

class Asset
  include DataMapper::Resource
  
  property :id, B62EncodedRandomIndex, :key => true
  property :discriminator, Discriminator
  property :client, String, :nullable => false
  property :filename, String
  property :original_filename, String
  property :mimetype, String
  property :original_mimetype, String
  property :state, String  # controlled by the state_machine
  property :queued_at, DateTime
  property :processing_started_at, DateTime

  property :upload_success_redirect_url, String
  property :upload_failure_redirect_url, String
  property :notification_url, String
  property :notification_state, String  # not_needed, delivered, delivery_failed, gave_up
  property :last_notification_sent_at, DateTime

  property :updated_at, DateTime
  property :created_at, DateTime

  state_machine :initial => :empty do
#     before_transition :log_state_change
#     after_transition  :pending => :authorized, :authorized => :captured do
#       # Update RSS feed...
#     end

    event :upload_accepted do
      transition :empty => :pending
    end

    event :disapprove do
      transition [:pending, :ok] => :disapproved
    end

    event :skip_processing do
      transition [:pending, :disapproved, :processing_error] => :ok
    end

    event :queue_for_processing do
      transition [:pending, :disapproved, :processing_error] => :queued_for_processing
    end

    event :processing_started do
      transition :queued_for_processing => :processing
    end
 
    event :processing_successful do
      transition :processing => :ok
    end

    event :processing_failed do
      transition :processing => :processing_error
    end
  end  

  class AssetError < StandardError; end
  class NoFileSubmitted < AssetError; end
  class AssetNotEmpty < AssetError; end
  class MimeTypeBlacklisted < AssetError; end
  class NotificationError < AssetError; end
  
  def self.next_job
    # TODO: Doesn't work --- WHY??
    # self.first(:status => "queued")
    
    self.all(:status => "queued").sort_by { |o| o.created_at }.first
  end
  
  def self.outstanding_notifications
    # TODO: Do this in one query
    self.all(:notification.not => "success", :notification.not => "error", :status => "success") +
    self.all(:notification.not => "success", :notification.not => "error", :status => "error") 
  end
    
  # reimplement this in subclasses that have have derived assets
  def obliterate!
    # TODO: should this raise an exception if the file does not exist?
    self.delete_from_store
    self.destroy
  end

  # basic acceptance of uploaded file
  def accept_upload(file)
    raise NoFileSubmitted if !file or file.blank?
    raise AssetNotEmpty unless self.empty?  # when uploading to a non empty asset
    mimetype = MIME.check(file[:tempfile].path).type
    raise MimeTypeBlacklisted if Asset.mimetype_blacklist.include? mimetype
  rescue => e
    raise e
  else
    self.filename = self.id + File.extname(file[:filename])
    self.original_filename = file[:filename].split("\\\\").last  # split out any directory path Windows adds in
    self.mimetype = mimetype
    self.original_mimetype = file[:content_type]
    FileUtils.mv(file[:tempfile].path, tmp_file_path)  # move file into our tmp location
    upload_accepted  # update state
  end
  
  # typically reimplemented in subclasses
  # used to cast the asset to its specific type in the recast! method
  def self.accepts_file?(tmp_file, mimetype)
    true
  end

  # this is typically re-implemented in subclasses
  def process_payload
    skip_processing  # generic assets are not processed (yet)
    send_to_store
  end

  # change the discriminator based on the mime_type returns an instance of 'itself'
  # exclamation mark reminds us that this method _saves_ the asset...
  def recast!
    [Video, Image].each do |klass|
      if klass.accepts_file?(tmp_file_path, mimetype)
        self.discriminator = klass
        save
        return klass.get(self.id)
      end
    end
    save
    return self
  end

  # returns an instance of the 'id' asset, but as its specific type... (Video, Image or... Asset)
  # if it cannot be found it raises an exception (therefor the exclamation mark)
  def self.get_and_cast!(id)
    d = repository.adapter.query(%Q{SELECT discriminator FROM assets WHERE id = '#{id}'})[0]
    raise DataMapper::ObjectNotFoundError unless d
    klass = Kernel.const_get d
    klass.get! id
  end

  def self.mimetype_blacklist
    %w{something/x-wrong with-these/x-mimetypes}
  end
  


  # Interaction with Store
  # ======================

  def url
    Store.url(filename)
  end

  def send_to_store
    Store.set(filename, tmp_file_path)
  end
  
  def fetch_from_store
    Store.get(filename, tmp_file_path)
  end
  
  # Deletes the video file without raising an exception if the file does 
  # not exist.
  def delete_from_store
    Store.delete(filename)
  rescue AbstractStore::FileDoesNotExistError
    false
  end
  


  

  # Notifications
  # =============
  
  def notification_wait_period
    (Merb::Config[:notification_frequency] * self.notification.to_i)
  end
  
  def time_to_send_notification?
    return true if self.last_notification_at.nil?
    Time.now > (self.last_notification_at + self.notification_wait_period)
  end
  
  def send_notification
    raise "You can only send the status of encodings" unless self.encoding?
    
    self.last_notification_at = Time.now
    begin
      self.parent_video.send_status_update_to_client
      self.notification = 'success'
      self.save
      Merb.logger.info "Notification successfull"
    rescue
      # Increment num retries
      if self.notification.to_i >= Merb::Config[:notification_retries]
        self.notification = 'error'
      else
        self.notification = self.notification.to_i + 1
      end
      self.save
      raise
    end
  end
  
  def send_status_update_to_client
    Merb.logger.info "Sending notification to #{self.state_update_url}"
    
    params = {"video" => self.show_response.to_yaml}
    
    uri = URI.parse(self.state_update_url)
    http = Net::HTTP.new(uri.host, uri.port)

    req = Net::HTTP::Post.new(uri.path)
    req.form_data = params
    response = http.request(req)
    
    unless response.code.to_i == 200# and response.body.match /ok/
      ErrorSender.log_and_email("notification error", "Error sending notification for parent video #{self.id} to #{self.state_update_url} (POST)

REQUEST PARAMS
#{"="*60}\n#{params.to_yaml}\n#{"="*60}

RESPONSE
#{response.code} #{response.message} (#{response.body.length})
#{"="*60}\n#{response.body}\n#{"="*60}")
      
      raise NotificationError
    end
  end


  def to_json
    result = {}
    %w{id discriminator filename original_filename mimetype original_mimetype state queued_at processing_started_at upload_success_redirect_url upload_failure_redirect_url notification_url notification_state last_notification_sent_at updated_at created_at}.each do |p|
      value = self.send(p)
      if p == 'discriminator'
        result['type'] = value.to_s == 'Asset' ? 'Generic' : value.to_s
      else
        result[p] = value.to_s if value  # actually to_json is better, but is seems to have a problem...
      end
    end
    result.to_json
  end

private

  def tmp_file_path
    Merb::Config[:tmp_dir] / filename
  end

#   def compose_tmp_filename(*args)
#     compose_path(:tmp_dir, *args)
#   end
  
  def compose_path(option, *args)
    Merb::Config[option] / args.map { |e| e.to_s }.join('_')
  end
end
