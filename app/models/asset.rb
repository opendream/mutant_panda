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
  property :queued_for_processing_at, DateTime
  property :processing_started_at, DateTime
  property :processing_finished_at, DateTime

  property :upload_success_redirect_url, String
  property :upload_failure_redirect_url, String
  property :notification_url, String
  property :notification_tries, Integer
  property :notification_state, String  # again see state_machine
  property :last_notification_sent_at, DateTime

  property :updated_at, DateTime
  property :created_at, DateTime

  state_machine :initial => :empty do
    after_transition  all => :queued_for_processing do
      self.queued_for_processing_at = Time.now
    end
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
      transition [:pending, :disapproved, :processing_error, :ok] => :queued_for_processing
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

 # unset, not_needed, pending, delivered, delivery_failed, gave_up
  state_machine :notification_state, :initial => :notification_unset do
    event :notification_not_needed do
      transition all => :notification_not_needed
    end
    event :start_sending_notification do
      transition all => :notification_pending
    end
    event :notification_delivery_successful do
      transition [:notification_pending, :notification_delivery_failed] => :notification_delivered
    end
    event :notification_delivery_failed do
      transition [:notification_pending, :notification_delivery_failed] => :notification_delivery_failed
    end
    event :give_up_notification_delivery do
      transition [:notification_delivery_failed] => :notification_given_up
    end
  end


  class AssetError < StandardError; end
  class NoFileSubmitted < AssetError; end
  class AssetNotEmpty < AssetError; end
  class MimeTypeBlacklisted < AssetError; end
  class NotificationError < AssetError; end


  # basic acceptance of uploaded file
  def accept_upload(file)
    raise NoFileSubmitted if !file or file.blank?
    raise AssetNotEmpty unless self.empty?  # when uploading to a non empty asset
    mimetype = MIME.check(file[:tempfile].path).type
    raise MimeTypeBlacklisted if Asset.mimetype_blacklist.include? mimetype
    self.filename = self.id + File.extname(file[:filename])
    self.original_filename = file[:filename].split("\\\\").last  # split out any directory path Windows adds in
    self.mimetype = mimetype
    self.original_mimetype = file[:content_type]
    FileUtils.mv(file[:tempfile].path, tmp_file_path)  # move file into our tmp location
    self.upload_accepted  # update state
  end
  
  # used to cast the asset to its specific type in the recast! method
  # typically reimplemented in subclasses
  def self.accepts_file?(tmp_file, mimetype)
    raise NotImplementedError.new("This method is only implemented in subclasses")
  end

  # this method is called within the upload request, therefor it should finish
  # within reasonable time. more put heavy processing in diverted_processing()
  # typically reimplemented in subclasses
  def initial_processing
    raise NotImplementedError.new("This method is only implemented in subclasses")
  end

  # this method is called by the process queue worker. put time intensive processing
  # jobs in here.
  # typically reimplemented in subclasses
  def diverted_processing
    raise NotImplementedError.new("This method is only implemented in subclasses")
  end

  # change the discriminator based on the mime_type returns an instance of 'itself'
  # exclamation mark reminds us that this method _saves_ the asset...
  def recast!
    [Video, Image, Generic].each do |klass|
      if klass.accepts_file?(tmp_file_path, mimetype)
        self.discriminator = klass
        save!
        return klass.get(self.id)
      end
    end
    save!
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


  def self.next_job
    # TODO: Test this!!!!
    self.first(:state => "queued_for_processing", :order => [:queued_for_processing_at])
#     (id, d) = repository.adapter.query(%Q{
#       SELECT id, discriminator FROM assets
#       WHERE state = 'queued_for_processing'
#       ORDER BY queued_for_processing_at LIMIT 1})[0].to_a
#     return false unless id and d
#     klass = Kernel.const_get d
#     klass.get! id
  end

  # reimplement this in subclasses that have have derived assets
  def obliterate!
    # TODO: should this raise an exception if the file does not exist?
    self.delete_from_store
    self.destroy
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
  
  def self.outstanding_notifications
    self.all(:notification_state => ['notification_pending', 'notification_delivery_failed'],
             :state => ['ok', 'processing_error'])
  end
  
  def notification_wait_period
    (Merb::Config[:notification_frequency] * self.notification_tries.to_i)
  end
  
  def time_to_send_notification?
    return true if self.last_notification_sent_at.blank?
    Time.now > (self.last_notification_sent_at + self.notification_wait_period)
  end
  
  def send_notification
    if self.notification_url.blank?
      self.notification_not_needed!
      # sometimes the previous line doesnt work, this makes sure it works TODO isolate and file this bug
      self.notification_state = 'notification_not_needed'  
      self.save
      return true
    end
    self.last_notification_sent_at = Time.now
    begin
      self.send_status_update_to_client
      self.notification_delivered
      self.save
      Merb.logger.info "Notification successfully sent for asset '#{id}'"
    rescue
      if self.notification_tries.to_i >= Merb::Config[:notification_tries]
        self.give_up_notification_delivery
        self.notification_state = 'give_up_notification_delivery'
      else
        self.notification_tries = self.notification_tries.to_i + 1
      end
      self.save
      raise
    end
  end
  
  def send_status_update_to_client
    Merb.logger.info "Sending notification to #{self.notification_url} for asset '#{id}'"
    uri = Kernel::URI.parse(self.notification_url)
    http = Net::HTTP.new(uri.host, uri.port)
    req = Net::HTTP::Post.new(uri.path)
    req.form_data = { id => self.to_json }.to_json
    response = http.request(req)
    if response.code.to_i == 200  # and response.body.match /ok/
      self.notification_delivered
    else
      # TODO decide if we want this error logger or merb-exception
      ErrorSender.log_and_email("notification error", "Error sending notification for parent video #{self.id} to #{self.notification_url} (POST)

REQUEST PARAMS
#{"="*60}\n#{params.to_yaml}\n#{"="*60}

RESPONSE
#{response.code} #{response.message} (#{response.body.length})
#{"="*60}\n#{response.body}\n#{"="*60}")
      
      raise NotificationError
    end
  end


# work this out... look at the show_response method of panda as well

#   # since to_json has some issues (im afraid ActiveSupport related) we do it like this..
#   def to_json
#     result = {}
#     %w{id discriminator filename original_filename mimetype original_mimetype state queued_at processing_started_at upload_success_redirect_url upload_failure_redirect_url notification_url notification_state last_notification_sent_at updated_at created_at}.each do |p|
#       value = self.send(p)
#       if p == 'discriminator'
#         result['type'] = value.to_s
#       else
#         result[p] = value.to_json if value  # actually to_json is better, but is seems to have a problem...
#       end
#     end
#     result.to_json
#   end

protected

  def tmp_file_path(filename = nil)
    Merb::Config[:tmp_dir] / (filename or self.filename)
  end

end
