if Merb::Config[:videos_store] == :s3

class S3VideoObject < AWS::S3::S3Object
  set_current_bucket_to Merb::Config[:s3_videos_bucket]
end

class S3Store < AbstractStore

  DELAY = 3

  def initialize
    raise RuntimeError, "You must specify videos_domain and s3_videos_bucket to use s3 storage" unless Merb::Config[:videos_domain] && Merb::Config[:s3_videos_bucket]
    
    AWS::S3::Base.establish_connection!(
      :access_key_id     => Merb::Config[:access_key_id],
      :secret_access_key => Merb::Config[:secret_access_key],
      :persistent => false
    )
  end
  
  def self.create_bucket
    AWS::S3::Bucket.create(Merb::Config[:s3_videos_bucket])
  end
  
  # Set file. Returns true if success.
  def set(key, tmp_file)
    begin
      retryable(:tries => 5, :delay => DELAY) do
        Merb.logger.info "Upload to S3"
        S3VideoObject.store(key, File.open(tmp_file), :access => :public_read)
      end
    rescue AWS::S3::S3Exception
      Merb.logger.error "Error uploading #{key} to S3"
      raise
    else
      true
    end
  end
  
  # Get file.
  def get(key, tmp_file)
    begin
      retryable(:tries => 5, :delay => DELAY) do
        File.open(tmp_file, 'w') do |file|
          Merb.logger.info "Fetch from S3"
          S3VideoObject.stream(key) {|chunk| file.write chunk}
        end
      end
    rescue AWS::S3::S3Exception
      Merb.logger.error "Tried to get #{key} from the store but the file does not exist"
      raise FileDoesNotExistError, "#{key} does not exist"
    else
      true
    end
  end
  
  # Delete file. Returns true if success.
  def delete(key)
    begin
      retryable(:tries => 5, :delay => DELAY) do
        Merb.logger.info "Deleting #{key} from S3"
        S3VideoObject.delete(key)
      end
    rescue AWS::S3::S3Exception
      Merb.logger.error "Tried to get #{key} from the store but the file does not exist"
      raise FileDoesNotExistError, "#{key} does not exist"
    else
      true
    end
  end
  
  # Return the publically accessible URL for the given key
  def url(key)
    %(http://#{Merb::Config[:videos_domain]}/#{key})
  end
end

end
